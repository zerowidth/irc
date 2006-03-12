require 'singleton'
require 'monitor' # for synchronization
require 'irc/message'
require 'irc/client'

module IRC
  
  class PluginHandler
    include Singleton # only one global instance!
    
    # how long to wait for a thread to finish before checking the next one
    # this is used by the janitor thread to clean up threads
    THREAD_READY_WAIT = 0.1 # seconds
    
    # to use PluginHandler, call PluginHandler.instance.
    # this class is a singleton so the plugin self-registration code is nice
    # and easy to read
    def initialize
      @plugins = [] # list of plugins (object instances, instantiated on registration)
      @handlers = {} # list of handlers for various types
      @threads = [] # list of threads created by plugin dispatch
      # janitor cleans up any dead threads and catches exceptions raised within
      @janitor = Thread.new { cleanup_threads() }
    end
    
    # load single plugin
    def load_plugin(path)
      #p path
      # wrap this in exception handling so syntax errors don't cause problems
      load path
    end
    
    # load plugins from a specified path
    def load_plugins(path)
#p      Dir[path+'/*.rb']
    end
    
    # pluginclass is a plugin class derived from Plugin
    # this class method allows register_plugin to be called from anywhere
    # in the code, regardless of whether an instance of PluginHandler exists or not yet.
    def self.register_plugin(pluginclass,*types)
     PluginHandler.instance.register_plugin(pluginclass,types)
    end

    # this is what actually does the registration
    def register_plugin(pluginclass,*types)
      # check to make sure this plugin hasn't already been registered
      unless @plugins.find {|p| p.class == pluginclass }
        # make a new one
        plugin = pluginclass.new
        plugin.extend(MonitorMixin)
        
        # add it to our list of plugins (to call when shutting down)
        @plugins << plugin
      
        # add the plugin to the requested handlers
        types.flatten! # allow arrays to be passed in too
        if types.include? :all
          add_plugin(:all,plugin)
        else
          types.each { |type| add_plugin(type,plugin) }
        end
      else # plugin's been registered already
        puts "warning: #{pluginclass} has been registered already"
      end
    end

    def dispatch_message(message)
      type = message.message_type
      method_name = method_for(type)
      
      #puts "dispatching #{method_name}"
      
      # handle plugins registered for individual types
      if @handlers[type]
        @handlers[type].each do |plugin|
          # wrap the actual dispatch into a thread so long-running plugin handlers
          # don't lock up the client. this is a serious concurrency issue!
          # yeah yeah, this could cause concurrency issues, but it's fine for now    
          # 
          # haha! it wasn't fine :( nick handling would step on each other since
          # the test cases send messages so fast. added code so access to a particular
          # plugin is synchronized.
          # this isn't ideal, since some plugin methods *don't* have concurrency problems
          # like, say, grabbing some external resource and returning it.
          # only plugins that modify internal variables like client context should
          # be synchronized. TODO: figure this out...
          @threads << Thread.new do
            plugin.synchronize do
              plugin.method(method_name).call(message) if plugin.respond_to? method_name
            end
          end
        end
      end
      
      # handle plugins registered for all messages
      if @handlers[:all]
        @handlers[:all].each do |plugin|
          plugin.message(message)
        end
      end

    end
    
    def shutdown
      @threads.each { |thread| thread.kill }
      @plugins.each do |plugin|
        plugin.teardown
      end
      @plugins = []
      @handlers = {}
    end

    private ####################

    def method_for(message_type)
      type = message_type.to_s.downcase
      # prepend 'm' for numeric message types
      if type =~ /^\d/
        type = 'm' + type
      end
      type
    end

    def add_plugin(index,plugin)
      @handlers[index] ||= []
      # don't register a plugin twice
      @handlers[index] << plugin unless @handlers[index].include? plugin
    end
    
    # janitor thread. this gets started with PluginHandler's instantiation
    # and never gets killed (since there's currently no explicit way to tell
    # PluginHandler to start up 'services' again)
    # TODO: see if there's a cleaner way of handling this...
    def cleanup_threads
      loop do
        # join up with threads so exceptions get logged
        begin
          @threads.each { |thread| thread.join(THREAD_READY_WAIT) }
        rescue => e
          # log exceptions here...
          puts "exception caught in plugin handler thread: #{e}"
          #puts e.backtrace[0]
        end
        sleep(THREAD_READY_WAIT) if @threads.empty? # no wheel-spinning allowed!
        @threads.delete_if {|thread| !thread.alive?}
      end
    end

  end # class PluginHandler
  
  # base class for Plugin, inherit from this whenever you want to create plugins
  # teardown is called when the plugin handler is shutting everything down
  # overload name, help, setup, and teardown as required.
  # register a plugin by calling 
  # ##### TODO: DOCUMENT THIS BETTER
  # PluginHandler.register_plugin(<class>, ... )
  # 
  # A plugin can register for one or more or all messages. 
  # The method invoked on the plugin can either be explicitly specified, or it will default
  # to the lowercase text value of the command: PRIVMSG --> calls privmsg, 
  # RPL_WELCOME --> m001 (m is prepended)
  # if registered for all messages, the message() method is invoked
  #  
  # Oh, and be careful when touching @client, or @client.config, know what you're doing.
  # @client is never actually given to the plugin explicitly, but it can be extracted
  # from any incoming message with ease
  class Plugin
    
    def initialize
    end

    # nothing is written to handle this yet    
#    def help
#      "no help defined for #{name()}"
#    end

    def name
      self.class.to_s
    end
    
    # teardown is called when the irc client is shutting down. 
    # use this to clean up db connections, etc.
    def teardown
    end
    
  end
  
end