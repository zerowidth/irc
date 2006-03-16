=begin IRC::Client

Client is the main class that ties everything together.

=end

# network
require 'irc/connection'

# command queues and handling
require 'irc/client_commands'
require 'irc/command_queue'

# config and state
require 'irc/config'
require 'irc/synchronized_hash'

# plugins and dispatch
require 'irc/plugin_manager'

module IRC
  
class Client
  
  attr_reader :config # publically available for pre-run config (set to readonly when started)
  
  def initialize
    @command_queue = CommandQueue.new
    @queue_thread = nil # thread to handle emptying/processing the queue

    @config = Config.new # this stays the same across all start() calls
    @state = nil # initialized in start()
    
    @connection = nil

    @running = false
  end
  
  # basic control methods #############
  
  def start
    raise 'client already running' if @running
    @config.exception_unless_configured() # raises exceptions if configuration is insufficient
    
    # instantiate these here instead of in the constructor so start() can be called
    # multiple times -- can now stop and start the client as requested
    @state = SynchronizedHash.new
    @plugin_manager = PluginManager.new(@command_queue, @config, @state)

    @config.readonly! # no more changes!
    @connection = IRCConnection.new(@config[:host], @config[:port], @command_queue)
    @connection.start() # won't return until connection is made

    # ok, everything's good. set the running flag and enter the queue processing loop
    @running = true
    
    # register with the irc server
    @command_queue.add( RegisterCommand.new(@config[:nick], @config[:user], @config[:realname]) )
 
    start_queue_handler()
  end

  def quit(reason=nil)
    # prevent quit() being called twice
    raise 'client already exited' unless @running

    # set flags
    @running = false
    
    # tear everything down
    @queue_thread.kill()
    @plugin_manager.teardown()
    
    # let the server know why we left
    @connection.send("QUIT :#{reason}") if reason
    
    @connection.disconnect()

    # free up the config for writing again
    @config.writeable!
    
  end
  
  def wait_for_quit
    @queue_thread.join
  end
    
  private #############################
  
  def start_queue_handler
    @queue_thread = Thread.new do
      queue_loop()
    end
  end

  def queue_loop
    loop do # could use a flag here, but eh. dequeue() is a blocking call, this thread gets killed
      command = @command_queue.dequeue()
      case command.type
      # very few plugins will do this, and then only to call quit().
      # everything else should be handled through the queue
      # quit is done via the client, since the client quit method sends out 
      # a QUIT command to the server.
      when :uses_client
        command.execute(self) 
      when :uses_socket
        command.execute(@connection)
      when :uses_plugins
        command.execute(@plugin_manager)
      when :uses_queue
        command.execute(@command_queue)
      end
    end
  end

end

end # module