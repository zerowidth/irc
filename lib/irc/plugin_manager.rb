require 'irc/common'
require 'monitor'

module IRC
  
class PluginManager
  
  include MonitorMixin
  
  cattr_accessor :logger
  
  THREAD_READY_WAIT = 0.1 # seconds
  
  def self.register_plugin plugin
    @@plugins ||= []
    @@plugins << plugin
  end

  def initialize(command_queue, config, state)

    # these might not need to be local
    @command_queue = command_queue
    @config = config
    @state = state
    
    # this is executed before instantiating anything, so all the plugins
    # get a chance to register first.
    # This code is in the constructor to allow for reloading of plugins
    # in a convenient manner, and it also makes more sense for it to happen
    # during instantiation than in a separate method.
    # This method call will catch any exception thrown by the plugin while executing
    # load on each file, including syntax errors! test your code first!
    load_plugins_from_dir(@config[:plugin_dir]) if @config && @config[:plugin_dir]

    @plugins = [] # list of plugins
    
    @handlers = {} # list of commands for which plugins are registered
    
    @threads = [] # list of threads - run by dispatch, cleaned up by janitor thread
    @threads.extend(MonitorMixin) # wrap it up for safety
    @janitor = Thread.new { janitor_loop }
    
    # this "freezes" the state of the class variable @@plugins by instantiating everything
    @@plugins ||= {} # just in case
    @@plugins.uniq.each do |plugin_class|
      # instantiate each plugin

      plugin = plugin_class.new(command_queue, config, state)
      @plugins << plugin
    end
    
  end
  
  def dispatch(message)
    method_name = method_for(message.message_type)
    handlers = handlers_for method_name
    if handlers == [] then 
      method_name = :catchall
      handlers = handlers_for :catchall 
    end
    handlers.each do |plugin|
      # wrap this call in a thread:
      # - allows for exception handling elsewhere
      # - prevents long-running calls from locking up the client
      @threads.synchronize do
        @threads << Thread.new { plugin.method(method_name).call(message) }
      end
    end
  end
  
  # this is pretty much final. tears everything down, including plugins
  # it also kills any currently-running threads
  def teardown
    # kill any active threads
    # this synchronization is present to prevent additional messages from 
    # being dispatched while teardown is in progress
    @threads.synchronize do
      @threads.each { |thread| thread.kill }
    end

    # invoke teardown on plugins
    @plugins.each { |plugin| plugin.teardown }

    # remove dispatcher's ability to do anything
    @plugins = {}
    @handlers = {}
    
    # commit murder
    @janitor.kill
  end
  
  private #############################
  
  def load_plugins_from_dir(plugin_dir)
    dir = File.expand_path(plugin_dir)
    logger.info "loading plugins from #{dir}:"
    Dir.foreach(dir) do |entry| # not recursive!
      filename = dir + '/' + entry
      if File.file?(filename) && entry =~ /\.rb$/ # only load ruby files
        begin 
          load(filename)
          logger.info "loaded #{filename}"
        rescue Exception => e # catch any exceptions, including syntax errors
          # all exceptions are caught so reloading plugins won't cause the 
          # client to crash.
          logger.warn "Plugin Manager caught exception #{e}"
          logger.warn e.backtrace[0]
        end
      end
    end
    
  end
  
  # determine which method to call on the plugins
  def method_for(message_type)
    type = message_type.to_s.downcase
    # prepend 'm' for numeric message types
    type = 'm' + type if type =~ /^\d/
    type
  end
  
  def handlers_for method_name
    unless @handlers[method_name] then
      @handlers[method_name] = []
      @plugins.each do |plugin|
        @handlers[method_name] << plugin if plugin.respond_to? method_name
      end
    end
    @handlers[method_name]
  end
  
  def janitor_loop
    loop do
      
      # join up with threads temporarily so exceptions get logged
      begin
        @threads.each { |thread| thread.join(THREAD_READY_WAIT) }
      rescue ArgumentError => ae
        # in case of arity problems with dispatches, handle ArgumentError. otherwise
        # any exceptions will be exceptional, so log 'em
        logger.error "exception caught in plugin handler thread #{e.inspect}"
        logger.error e.backtrace[0]
      rescue => e
        logger.warn "exception caught in plugin handler thread: #{e.inspect}"
        logger.warn e.backtrace[0]
      end
      
      # delete any threads that are done. synchronized so weirdness doesn't happen
      # when another dispatch is going on
      @threads.synchronize do
        @threads.delete_if {|thread| !thread.alive?}
      end

      sleep(THREAD_READY_WAIT) if @threads.empty? # no wheel-spinning allowed!
    end #loop
  end
  
end

end # module