=begin IRC::Client

Client is the main class that ties everything together.

=end

# network
require 'irc/connection'

# client commands
require 'irc/client_commands'

# config and state
require 'irc/config'
require 'irc/synchronized_hash'

# plugins and dispatch
require 'irc/plugin_manager'
require 'irc/core_plugin' # registers core plugin for basic services

# logging
require 'irc/cattr_accessor'
require 'logger'

module IRC
  
  DEFAULT_LOG_LEVEL = :info

class Client
  
  attr_reader :config # publically available for pre-run config (set to readonly when started)
  attr_accessor :logger
  
  def initialize(configfile=nil)
    # initialize logging
    @logger = Logger.new(STDOUT) # TODO: make this more flexible
    [Message, IRCConnection, PluginManager, Plugin].each do |klass|
      klass.logger ||= @logger
    end
    @logger.level = Logger.const_get(DEFAULT_LOG_LEVEL.to_s.upcase)

    @command_queue = Queue.new
    @queue_thread = nil # thread to handle emptying/processing the queue

    @config = Config.new(configfile) # this stays the same across all start calls
    @state = nil # initialized in start
    
    @connection = nil

    @running = false
  end
  
  # basic control methods #############
  
  def start
    raise 'client already running' if @running
    @config.exception_unless_configured # raises exceptions if configuration is insufficient
    
    logger.info "starting client"
    
    # instantiate these here instead of in the constructor so start can be called
    # multiple times -- can now stop and start the client as requested
    @state = SynchronizedHash.new
    @plugin_manager = PluginManager.new(@command_queue, @config, @state)

    @config.readonly! # no more changes!
    connect # won't return until connected
    
    # ok, everything's good. set the running flag and enter the queue processing loop
    @running = true
    
    # register with the irc server
    register_with_server
 
    start_queue_handler
  end
  
  def reconnect
    # reconnect to server (do this when getting an ERROR message, ping timeout, etc)
    logger.info "reconnecting"
    @connection.disconnect
    connect
    register_with_server # reregister
  end

  def quit(reason=nil)
    # prevent quit being called twice
    raise 'client already exited' unless @running

    logger.info "client quitting"

    # set flags
    @running = false

    # tear everything down
    @plugin_manager.teardown

    # let the server know why we left
    @connection.send("QUIT :#{reason}") if reason

    @connection.disconnect

    # free up the config for writing again
    @config.writeable!  
      
    # don't do this until the very end, since this is what's being waited on. ALSO:
    # if this method is being called from a QuitCommand, this is running inside 
    # queue_thread, and this kill, in effect, is committing suicide!
    @queue_thread.kill
  end
  
  def wait_for_quit
    @queue_thread.join
  end
    
  private #############################
  
  def connect
    @connection = IRCConnection.new(@config[:host], @config[:port], @command_queue)
    @connection.start # won't return until connection is made
  end
  
  def start_queue_handler
    @queue_thread = Thread.new do
      queue_loop
    end
  end

  def queue_loop
    # could use loop do here, since this method blocks up on dequeue.
    # however: using the quit flag means this (internal!) loop/thread can be 
    # stopped after only one dequeue by setting the quit flag so it exits immediately.
    # this speeds up testing, so until @quit it is!
    until @quit do
      command = @command_queue.pop
      case command
      # very few plugins will do this, and then only to call quit.
      # everything else should be handled through the queue
      # quit is done via the client, since the client quit method sends out 
      # a QUIT command to the server.
      when ClientCommand
        command.execute(self) 
      when SocketCommand
        command.execute(@connection)
      when PluginCommand
        command.execute(@plugin_manager)
      when QueueCommand
        command.execute(@command_queue)
      when QueueConfigStateCommand
        command.execute(@command_queue, @config, @state)
      end
    end
  end
  
  def register_with_server
    @command_queue << RegisterCommand.new(@config[:nick], @config[:user], @config[:realname])
  end

end

end # module