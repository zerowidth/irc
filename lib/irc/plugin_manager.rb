require 'irc/plugin'
require 'monitor'

module IRC
  
class PluginManager
  
  include MonitorMixin
  
  THREAD_READY_WAIT = 0.1 # seconds
  
  def self.register_plugin(plugin, *commands)
    @@plugins ||= {}
    @@plugins[plugin] ||= []
    commands.each do |command|
      @@plugins[plugin] << command unless @@plugins[plugin].include? command
    end
  end

  def initialize(command_queue, config, state)
    super() # initialize monitor mixin
    
    # these might not need to be local
    @command_queue = command_queue
    @config = config
    @state = state
    
    @plugins = [] # list of plugins
    @handlers = {} # list of commands for which plugins are registered
    
    @threads = [] # list of threads - run by dispatch, cleaned up by janitor thread
    @janitor = Thread.new { janitor_loop() }
    
    # this "freezes" the state of the class variable @@plugins by instantiating everything
    @@plugins ||= {} # just in case
    @@plugins.each_pair do |plugin_class,commands|
      # instantiate each plugin
      plugin = plugin_class.new(command_queue, config, state)
      @plugins << plugin
      # record which commands each plugin is registered for
      commands.each do |command|
        @handlers[command] ||= []
        @handlers[command] << plugin
      end
    end
    
  end
  
  def dispatch(message)
    synchronize do # see teardown()
      type = message.message_type
      method_name = method_for(type)
    
      if @handlers[type]
        @handlers[type].each do |plugin|
          if plugin.respond_to? method_name
            # wrap this call in a thread:
            # - allows for exception handling elsewhere
            # - prevents long-running calls from locking up the client
            @threads << Thread.new { plugin.method(method_name).call(message) }
          end
        end # each do
      end # if handler exists
    end # synchronize block
  end
  
  # this is pretty much final. tears everything down, including plugins
  # it also kills any currently-running threads
  def teardown
    # this synchronization is present to prevent additional messages from 
    # being dispatched while teardown is in progress
    synchronize do
      # kill any active threads
      @threads.each { |thread| thread.kill }

      # invoke teardown on plugins
      @plugins.each { |plugin| plugin.teardown }

      # remove dispatcher's ability to do anything
      @plugins = {}
      @handlers = {}
      
      # commit murder
      @janitor.kill
    end
  end
  
  private #############################
  
  # determine which method to call on the plugins
  def method_for(message_type)
    type = message_type.to_s.downcase
    # prepend 'm' for numeric message types
    type = 'm' + type if type =~ /^\d/
    type
  end
  
  def janitor_loop()
    loop do
      
      # join up with threads temporarily so exceptions get logged
      begin
        @threads.each { |thread| thread.join(THREAD_READY_WAIT) }
      rescue => e
        # log exceptions here...
#        puts "exception caught in plugin handler thread: #{e}"
#        puts e.backtrace[0]
      end
      
      # delete any threads that are done
      @threads.delete_if {|thread| !thread.alive?}
      
      sleep(THREAD_READY_WAIT) if @threads.empty? # no wheel-spinning allowed!
    end #loop
  end
  
end

end # module