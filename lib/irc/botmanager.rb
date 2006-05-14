require 'irc/client'
require 'drb'

module IRC
  # BotManager provides an interface suitable for starting and storing Client
  # instances via DRb.
  class BotManager

    include DRb::DRbUndumped

    def initialize(client_config_file)
      @clients = {} # hash of ClientProxy objects
      @client_config_file = client_config_file # base config for all Clients
    end
    
    def client(client_name)
      get_client(client_name)
    end
    
    def remove_client(client_name)
      client = @clients[client_name]
      return unless client
      client.quit 'client quit' if client.running?
      @clients.delete client_name
    end
      
    def shutdown
      @clients.each_value do |client|
        if client and client.running?
          client.quit 'manager shutdown'
        end
      end
      @clients = {}
    end
    
    private
    
    def get_client(client_name)
      unless @clients[client_name]
        client = Client.new(@client_config_file)
        @clients[client_name] = ClientProxy.new(client)
      end
      @clients[client_name]
    end
    
  end
  
end