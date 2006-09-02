=begin IRC::Client

Client is the main class that ties everything together.

=end

require 'irc/connection' # network
require 'notification' # callbacks
require 'irc/config' # config
require 'irc/synchronized_hash' # state
require 'irc/plugin_manager' # plugins and dispatch
require 'irc/plugins/core_plugin' # registers core plugin for basic services
require 'irc/common' # cattr_accessor
require 'irc/rfc2812'
require 'irc/message'

require 'logger' # logging
require 'drb' # undumped

module IRC
  
  DEFAULT_LOG_LEVEL = :info

class Client

  include Notification
  
  cattr_accessor :logger
  
  attr_reader :config # publically available for pre-run config (set to readonly when started)
  attr_reader :state # for viewing the client's state
  
  def initialize(configfile=nil)
    
    # set up the logging...
    unless logger()
      self.logger = Logger.new(STDOUT)
    end
    [Message, Connection, PluginManager, Plugin].each do |klass|
      klass.logger ||= self.logger
    end

    @config = Config.new(configfile) # this stays the same across all start calls!
    @state = SynchronizedHash.new

    @connection = nil
  end
  
  # basic control methods #############
  
  def start
    raise 'client already connected' if connected?
    @config.exception_unless_configured # raises exceptions if configuration is insufficient
    
    logger.info "starting client"
    
    @state ||= SynchronizedHash.new

    # instantiate the plugins and set up the callbacks before 
    # freezing the config and opening the connection
    @plugins = PluginManager.instantiate_plugins(self)
    @plugins.each do |plugin|
      add_observer plugin, :all
      # idea: check each plugin and warn about any public methods that don't 
      # match the list of standard client-provided callbacks (for debugging help)
    end

    connect
  end
  
  def quit(reason=nil)
    # prevent quit being called twice
    raise 'client not connected' unless connected?
    logger.info "client quitting"

    @reconnect = false # disable auto reconnect

    # let the server know why we left
    @connection.send("QUIT :#{reason}") if reason
    
    # tear down the plugins
    notify :teardown
    
    # clear out the plugins
    @plugins.each { |plugin| delete_observer plugin }
    
    # kill the connection
    @connection.disconnect
    @connection = nil

    # free up the config for writing again
    @config.writeable!
    
    # clear out the state
    @state = SynchronizedHash.new
  end
  
  def wait_for_quit
    while @reconnect
      @connection.wait_for_disconnect if connected?
      sleep(0.1)
    end
  end
  
  def connected?
    !@connection.nil? && @connection.connected?
  end
  
  def merge_config(config)
    @config.merge! config
  end
  
  # ----- public commands -----
  def send_raw(data)
    @connection.send(data)
  end
  
  def change_nick(nick)
    # save the new nick, but don't change the existing nick until the server
    # sends a response back saying it was successful (this is handled elsewhere).
    @state[:newnick] ||= []
    @state[:newnick] << nick
    @connection.send("NICK #{nick}")
  end
  
  def join_channel(chan)
    @connection.send("JOIN #{chan}")
  end
  
  def leave_channel(chan, reason=nil)
    @connection.send("PART #{chan}" + (reason ? " :#{reason}" : '') )
  end
  
  def channel_message(chan, msg)
    @connection.send("PRIVMSG #{chan} :#{msg}")
  end
  alias :private_message :channel_message # same params, same code
  
  def channel_notice(chan, notice)
    @connection.send("NOTICE #{chan} :#{notice}")
  end
  alias :private_notice :channel_notice

  # ----- callbacks -----
  
  # connection callbacks:
  
  def connected
    @config.readonly!
    register_with_server
    @reconnect = true
    notify :connected
  end
  
  def disconnected
    # leaves state intact!
    logger.info('client disconnected')
    @config.writeable!
    @state[:newnick] = [] # irrelevant now...
    notify :disconnected
    if @config[:auto_reconnect] && @reconnect
      logger.info('waiting for retry...')
      sleep @config[:retry_wait]
      logger.info('reconnecting')
      connect
    end
  end
  
  def data(data)
    notify :data, data
    # parse the data into a Message object
    msg = Message.parse(data)
    return unless msg # ignore dispatch if the message wasn't parsed right
    
    # now, do the higher-level callbacks:
    trigger_callbacks_for msg
  end
  
  def connection_error(error)
    notify :connection_error, error
  end
  
  private #############################
  
  def connect
    @connection = Connection.new(@config[:host], @config[:port])
    @connection.add_observer self, :all
    @connection.connect # won't return until connection is made
  end
  
  def register_with_server
    @connection.send("USER #{@config[:user]} 0 * :#{@config[:realname]}")
    change_nick(@state[:nick] || @config[:nick])
  end
  
  # this is the heart of the client's high-level callback functionality
  # threaded notifications are used when it is expected that non-critical
  # plugins will rely on them and possibly initiate long-running calls.
  #
  # callbacks happen on two levels:
  #   1: data(raw data)
  #   2: high-level callbacks, with whatever args
  #
  # 'who' is a MessageInfo::User object
  #
  # high-level callbacks tested thus far:
  #   :registered_with_server
  #   :nick_change(who, to_what)
  #   :nick_in_use(nick)
  #   :nick_invalid(nick)
  #   :server_ping(param)
  #   :server_error
  #   :joined_channel(who, chan)
  #   :left_channel(who, chan, reason)
  #   :quit_server(who, reason)
  #   :topic_changed(chan, new_topic, who_changed_it)
  #   :channel_name_list(chan, names)
  #   :channel_message(chan, message, who)
  #   :private_message(you, message, who)
  #   :channel_notice(chan, notice, who)
  #   :private_notice(you, notice, who)
  #   :disconnected
  #   :connected
  def trigger_callbacks_for(msg)
    case msg.message_type

    # ----- server messages
    when RPL_WELCOME
      notify :registered_with_server
    when CMD_PING
      notify :server_ping, msg.params[0] # server wants the params back
    when CMD_ERROR
      notify :server_error

    # ----- nick-related -----
    when CMD_NICK
      @state[:nick] = msg.params[0] if msg.prefix[:nick] == @state[:nick]
      threaded_notify :nick_changed, msg.prefix[:nick], msg.params[0]
    when ERR_NICKNAMEINUSE
      # nickname errors are deterministic, that is, the client keeps track of the 
      # state of attempted nick changes in @state, and the server responds to them
      # in order, so no additional info needs to be sent in the callback.
      # (this is tested)
      notify :nick_in_use
    when ERR_ERRONEUSNICKNAME
      notify :nick_invalid

    # ----- channel-related -----
    when CMD_JOIN
      threaded_notify :joined_channel, msg.user, msg.params[0]
    when CMD_PART
      threaded_notify :left_channel, msg.user, msg.params[0], msg.params[1]
    when CMD_QUIT
      threaded_notify :quit_server, msg.user, msg.params[0]
    when RPL_TOPIC # negative indices handle rfc and non-rfc commands
      threaded_notify :topic_changed, msg.params[-2], msg.params[-1], nil
    when CMD_TOPIC
      threaded_notify :topic_changed, msg.params[0], msg.params[1], msg.user
    when RPL_NAMREPLY
      @state[:scratch] ||= {}
      @state[:scratch][msg.params[-2]] ||= []
      # strip out leading mode characters: @, +, ~, etc.
      @state[:scratch][msg.params[-2]] += msg.params[-1].split.map { |name| name.gsub(/^[^a-zA-Z\[\]\\`_\^{}\|]/,'') }
    when RPL_ENDOFNAMES
      if @state[:scratch]
        threaded_notify :channel_name_list, msg.params[-2], ( @state[:scratch][msg.params[-2]] || [] )
        @state[:scratch].delete(msg.params[-2])
      else
        threaded_notify :channel_name_list, []
      end
    
    # ----- messaging -----
    when CMD_PRIVMSG
      if private?(msg)
        threaded_notify :private_message, msg.params[0], msg.params[1], msg.user
      else
        threaded_notify :channel_message, msg.params[0], msg.params[1], msg.user
      end
    when CMD_NOTICE
      if private?(msg)
        threaded_notify :private_notice, msg.params[0], msg.params[1], msg.user
      else
        threaded_notify :channel_notice, msg.params[0], msg.params[1], msg.user
      end

    end
  end

  # ----- helpers -----
  def private?(msg)
    msg.params[0] == @state[:nick]
  end
  
end

end # module