=begin IRC::Client

Client is the main class that ties everything together.

=end

require 'irc/connection' # network
require 'irc/client_commands' # client commands
require 'irc/config' # config
require 'irc/synchronized_hash' # state
require 'irc/plugin_manager' # plugins and dispatch
require 'irc/core_plugin' # registers core plugin for basic services
require 'irc/common' # cattr_accessor

require 'logger' # logging

module IRC
  
  DEFAULT_LOG_LEVEL = :info

class Client
  
  attr_reader :config # publically available for pre-run config (set to readonly when started)
  attr_reader :command_queue # publically available for adding things
  attr_reader :state # for viewing the client's state
  attr_accessor :logger
  
  def initialize(configfile=nil)
    # initialize logging
    @logger = Logger.new(STDOUT) # TODO: make this more flexible
    [Message, IRCConnection, PluginManager, Plugin].each do |klass|
      klass.logger ||= @logger
    end
    @logger.level = Logger.const_get(DEFAULT_LOG_LEVEL.to_s.upcase)

    @command_queue = Queue.new # external queue for telling the client what to do
    @data_queue = Queue.new # internal queue for data processing, etc.
    
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
    @plugin_manager = PluginManager.new(@data_queue, @config, @state)

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
    @connection.connect
#    connect
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
  
  # utility method to check if the client is running
  def running?
    @queue_thread != nil && @queue_thread.alive?
  end
    
  private #############################
  
  def connect
    @connection = IRCConnection.new(@config[:host], @config[:port], @data_queue)
    @connection.connect # won't return until connection is made
  end
  
  def start_queue_handler
    @queue_thread = Thread.new do
      queue_loop
    end
  end

  def queue_loop
    # hokay, here's a tricky section. 
    # there's two queues in Client, the data queue and the command queue.
    # The command queue is external: users of a Client instance have access to this.
    # The data queue is for internal use only (connection and plugins have access to it), 
    # and here's why: connect/disconnect handling. If the client gets disconnected, I wanted
    # the client to put everything else on hold until it got reconnected again. The difficulty
    # was that the reconnect code relies on the command queue, and it'd have been messy telling
    # the plugins or whomever to put things on the front of the queue so they had priority, etc.
    # So... this seemed like the simplest solution.   

    # tricky pop code, need to pop from both queues but pop is blocking, and also need
    # to avoid a busy loop (nonblocking pops on both)
    begin # need to ensure the transfer thread gets killed
      transfer_thread = nil

      # Could use loop do here, since this method blocks up on dequeue.
      # However: using the quit flag means this loop/thread can be 
      # stopped after only one dequeue by setting the quit flag so it exits immediately.
      # This speeds up testing, so until @quit it is!
      until @quit do
        command = @data_queue.pop
      
        case command
        # first handle a couple special instances, specifically, the connect/disconnect notices:
        when ClientConnectedCommand
          # start up the command queue transfer process
          transfer_thread = new_queue_transfer_thread unless transfer_thread && transfer_thread.alive?
          command.execute(@data_queue)
        when ClientDisconnectedCommand
          transfer_thread.kill # stop any processing of the command queue!
          command.execute(@data_queue, @config, @state)
        # ok, now the rest of 'em.
        when ClientCommand
          # Very few plugins will use a ClientCommand, and then generally only to call quit.
          # Everything else should pretty much be handled through the queue.
          # Quit is done via the client, since the client quit method sends out
          # a QUIT command to the server.
          # Generally the only exceptions are the connect/disconnect commands
          command.execute(self) 
        when SocketCommand
          command.execute(@connection)
        when PluginCommand
          command.execute(@plugin_manager)
        when QueueCommand
          command.execute(@data_queue)
        when QueueConfigStateCommand
          command.execute(@data_queue, @config, @state)
        end

      end
    ensure # this must always happen, even when the thread containing the queue loop is killed
      transfer_thread.kill if transfer_thread && transfer_thread.alive? # clean up
    end
  end
  
  def new_queue_transfer_thread
    Thread.new do
      loop do
        @data_queue << @command_queue.pop
      end      
    end
  end
  
  def register_with_server
    @data_queue << RegisterCommand.new(@config[:nick], @config[:user], @config[:realname])
  end

end

end # module