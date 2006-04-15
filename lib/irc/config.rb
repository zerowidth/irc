require 'yaml'

module IRC
  
  class Config
    
    # Config holds pre-runtime (host, port) configuration for the irc client.
    # Config is frozen while the bot is running to prevent changes. Runtime state is stored
    # elsewhere (state hash)
    
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
#      :plugin_dir => File.basename(File.dirname(__FILE__) + 'plugins')
      
    }.freeze
    
    def initialize(configfile=nil)
      @config = CONFIG_DEFAULTS.dup # .dup, otherwise changing @config tries to change CONFIG_DEFAULTS
      load_from_file(configfile) if configfile
    end

    def [](key)
      raise ConfigOptionRequired, key if @config[key] == :required
      @config[key]
    end
    
    def []=(key, val)
      raise "config is read-only" if readonly?
      @config[key] = val
    end
    
    def merge!(newdata)
      @config.merge! newdata
    end
    
    def readonly?
      @config.frozen?
    end
    
    def readonly!
      @config.freeze
    end
    
    def writeable!
      @config = @config.dup # unfreeze
    end
    
    # called by client before starting - gotta make sure everything's set up
    def exception_unless_configured
      required = @config.find_all {|key, val| val == :required }
      raise ConfigOptionRequired, "Required settings: " + required.inspect + 
        required.map {|key, val| key }.join(', ') unless required.empty?
    end
    
    private ############################
    
    def load_from_file(file)
      # this throws an exception if the file doesn't exist
      file_config = File.open( File.expand_path(file) ) {|f| YAML.load(f) }
      @config.merge!(file_config)
    end

    class ConfigOptionRequired < RuntimeError; end
  
  end
  
end
