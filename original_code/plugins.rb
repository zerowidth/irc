require 'find'

module IRC
  
  class Plugins
    
    def plugins
      @@plugins
    end
    
    def initialize(dir,client)
      @@client = client
      @@plugin_dir = File.expand_path(dir)
      @@plugins = {}
      @@messages = {}
      @@commands = {}
      @@threads = [] # threads started by the dispatchers
      # TODO AIEE horrible hack to kill just the threads started by dispatchers this memory area will
      # fill up with dead/finished threads and uaaaaa
      # something needs to be done about this, either periodically clean out dead/finished threads (hack)
      # or better, handle the thread registration properly somehow so subsets can be deleted/killed
      # as necessary
      @@init = true
    end

    def load_plugins
      Find.find(@@plugin_dir) do |file|
        if file =~ /\.rb$/
          begin
            puts "loading plugin #{file}"
            load(file)
          rescue Exception => e # in case of syntax errors, etc.
            puts "exception #{e} when trying to load plugin #{File.basename(file)}: #{e.backtrace[0]}"
          end
        end
      end
    end
    
    def reload_plugins()
      @@plugins.each_pair do |name, plugin|
        plugin.teardown
      end
      @@threads.each do |t|
        t.kill # kill all the threads that the plugin dispatcher started
      end
      @@threads = []
      @@plugins = {}
      @@messages = {}
      @@commands = {}
      load_plugins
    end
    
    # dispatches message to all the plugins that have registered for it
    def dispatch(message)
      return unless message.message_type
      # if it's a PRIVMSG dispatch the message to the command handlers
      dispatch_command(message) if message.message_type==CMD_PRIVMSG
      
      # dispatch the messages
      dispatch_message(message)
    end

    def Plugins.register_plugin(plugin, *messages)
      raise(ArgumentError,"Did you try to register this plugin outside of an IRC::Client instance?") unless @@init
      puts "registering plugin #{plugin.name} for #{messages.join(', ')}"
      plugin.client = @@client
      @@plugins[plugin.name] = plugin
      messages.each do |message|
        methodname = method_name(message)
        @@messages[methodname] ||= []
        @@messages[methodname] << plugin.name
      end
    end

    # register a plugin command (string), specifying privateonly if the command should
    # only be used in private, and command_method (name of method to invoke) if the command name 
    # is not an otherwise valid Ruby method name (e.g. registering a command '!!')
    # command is checked against reserved word list
    def Plugins.register_command(plugin, command, privateonly=false, command_method=nil)
      raise(ArgumentError,"Did you try to register this command outside an IRC::Client instance?") unless @@init
      puts "registering command #{command} for plugin #{plugin.name}" + 
        (command_method ? " using method #{command_method}" : '')
      if %w{initialize new help name setup teardown}.include?(command_method || command)
        puts "error: could not register #{command} for plugin #{plugin.name}. command method is reserved."
        return
      end
      plugin.client = @@client
      @@plugins[plugin.name] = plugin
      @@commands[command] ||= []
      @@commands[command] << [plugin.name, command_method || command, privateonly]
    end
    
    private 
    
    def dispatch_message(message)
      message_type = message.message_type
#puts "dispatching message #{message_type}"
      method = Plugins.method_name(message_type)
      return unless @@messages[method]
      @@messages[method].each do |plugin_name|
        p = @@plugins[plugin_name]
        if p.respond_to?(method)
          #puts "#{plugin_name} handling #{message_type}"
          @@threads << @@client.threads.new_thread(p, message,method) do |p, message, method|
            begin
              p.method(method).call(message)
            rescue Exception => e
              puts "error: exception #{e} raised by #{plugin_name}: #{e.backtrace[0]}" +
                " when handling #{message.raw_message}"
            end
          end
        else
          puts "warning: plugin #{plugin_name} asked to handle #{message_type} but couldn't!"
        end
      end # each
    end
    
    def dispatch_command(message)
      return unless message.params[1] =~ /^(\S+)(?:\s+|$)(.*)/
      command, args = $~.captures
      prefix = @@client.config.command_prefix
      has_prefix = command[0..(prefix.length-1)] == prefix
      is_private = message.private?
      prefix_in_private = @@client.config.require_prefix_in_private
      return if (!is_private && !has_prefix) || (is_private && prefix_in_private && !has_prefix)
      command = command[(prefix.length)..(command.length-1)] if has_prefix
      return unless @@commands[command]
      @@commands[command].each do |cmd|
        plugin_name, method, privonly = cmd
        plugin = @@plugins[plugin_name]
        if !is_private && privonly
          puts "#{plugin.name} skipping command #{command} because it's not private"
          next
        end
        puts "attempting to handle command #{command} using #{method}"
        if plugin.respond_to?(method)
          puts "#{plugin.name} handling command #{command}, calling #{method}"
          @@threads << @@client.threads.new_thread(plugin, message,method) do |plugin, message, method|
            begin
              plugin.method(method).call(message, command, args)
            rescue Exception => e
              puts "error: exception #{e} raised by #{plugin_name}: #{e.backtrace[0]}" + 
                " when handling #{message.raw_message}"
            end
          end
        else
          puts "warning: plugin #{plugin.name} asked to handle command #{command} but couldn't!"
        end
      end
    end

    def Plugins.method_name(message_type)
      message_type = message_type.downcase
      return 'm'+message_type if message_type.to_i != 0
      message_type
    end
    
  end
  
  class Plugin
    attr_writer :client

    def initialize
      @client = nil
    end
    
    def help
      "no help defined for #{name()}"
    end

    def name
      self.class.to_s
    end
    
    def setup
    end
    
    def teardown
    end
    
  end
  
end
