require 'yaml'

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
      :plugin_dir => File.basename(File.dirname(__FILE__) + 'plugins'),
      
      # state
      :channels => nil, # not an array, since it doesn't get duplicated
      
    }.freeze
    
    def initialize
      @config = CONFIG_DEFAULTS.dup # .dup or changing @config tries to change CONFIG_DEFAULTS
    end
    
# removed, does anyone ever call this?
# EDIT: why yes, as a matter of fact, Client#start does.
    def exception_unless_configured
      required = @config.find_all {|key, val| val == :required }
      raise ConfigOptionRequired, "Required settings: " + required.inspect + 
        required.map {|key, val| key }.join(', ') unless required.empty?
    end

# deal with this later...
#    def load_from_file(filename)
#      config_data = File.open(filename) {|f| YAML.load(f) }
#      config_data.each_pair { |key, val| @config[key.to_sym] = val }
#    end

    def [](key)
      raise ConfigOptionRequired, key if @config[key] == :required
      return @config[:oldnick] if key == :nick && @config[:oldnick]
      @config[key]
    end
    
    def []=(key, val)
      #puts "config changing #{key} to #{val}"
      @config[key] = val
    end

# alternate way of accessing config options. i like the [] accessor better
#    def method_missing(symbol, *args)
#      changing_option = symbol.to_s =~ /=$/
#      option = symbol.to_s.sub(/=$/,'').to_sym
#      
#      if @config.has_key?(option)
#        if changing_option
#          self[option] = args[0]
#        else
#          self[option]
#        end
#      else
#        super( symbol, *args )
#      end
#
#    end

    class ConfigOptionRequired < RuntimeError; end
  
  end
  
end