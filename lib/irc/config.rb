#require 'yaml'

module IRC
  
  class Config
    
    # Config holds pre-runtime (host, port) and runtime (nick, channels) for an irc bot.
    # All config options can be changed at runtime. This may or may not be a good idea
    # and it may or may not affect the current state of the running bot. Be careful.
    # I don't recomment futzing with @client.config from inside plugins unless you
    # know what you're doing!
    
    # if a default is set to :required, it needs to be set before things work
    # don't put an array in here, plz, since when that gets modified, so does
    # the constant. k.
    CONFIG_DEFAULTS = {
      # connection configuration
      :host => :required,
      :port => 6667,

      # client registration
      :nick => 'rbot',
      :user => 'rbot',
      :realname => 'ruby irc bot',
      
      # bot settings
      :retry_wait => 10, # seconds before retrying a connection
      
      # plugins
#      :plugin_dir => File.basename(File.dirname(__FILE__) + 'plugins'),
      
    }.freeze
    
    def initialize
      @config = CONFIG_DEFAULTS.dup # .dup or changing @config tries to change CONFIG_DEFAULTS
      @readonly = false # readonly locking, set by the client once things are "locked down"
    end

    def [](key)
      raise ConfigOptionRequired, key if @config[key] == :required
      @config[key]
    end
    
    def []=(key, val)
      raise "config is read-only" if readonly?
      #puts "config changing #{key} to #{val}"
      @config[key] = val
    end
    
    def readonly?
      @readonly
    end
    
    def readonly!
      @readonly = true
    end
    
    def writeable!
      @readonly = false
    end
    
    # called by client before starting - gotta make sure everything's set up
    def exception_unless_configured
      required = @config.find_all {|key, val| val == :required }
      raise ConfigOptionRequired, "Required settings: " + required.inspect + 
        required.map {|key, val| key }.join(', ') unless required.empty?
    end

    class ConfigOptionRequired < RuntimeError; end
  
  end
  
end