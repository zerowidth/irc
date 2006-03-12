require 'yaml'

module IRC
  
  class Config
    
    attr_reader :host
    attr_reader :port
    attr_reader :nick
    attr_reader :user
    attr_reader :realname
    attr_reader :retry_wait
    attr_reader :plugin_dir
    attr_reader :autojoin
    attr_reader :command_prefix
    attr_reader :require_prefix_in_private
    attr_reader :admin_pass
    attr_reader :operuser
    attr_reader :operpass
    
    attr_reader :cd
    
    def initialize
      begin
        config_data = File.open('config.yaml') {|f| YAML.load(f) }
        @cd = config_data
      rescue => e
        p e
      end
      
      def set_nick(newnick)
        @nick = newnick
      end
      
      # sensible, basic required defaults are included
      @host = config_data['host'] || 'localhost'
      @port = config_data['port'] || '6667'
      @nick = config_data['nick'] || 'rb2'
      @retry_wait = config_data['retry_wait'] || 10
      @plugin_dir = config_data['plugin_dir'] || './plugins'
      @autojoin = config_data['autojoin'] || nil
      @user = config_data['user'] || 'rb2'
      @realname = config_data['realname'] || 'ruby bot framework'
      @command_prefix = config_data['command_prefix'] || '!'
      @require_prefix_in_private = config_data['require_prefix_in_private'] || false
      @admin_pass = config_data['admin_pass'] || raise("must specify admin password in config, no defaults allowed here")
      @operuser = config_data['operuser'] || ''
      @operpass = config_data['operpass'] || ''
    end
  end
  
end
