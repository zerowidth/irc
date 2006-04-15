require 'irc/client'

module IRC
  # BotMaster provides an interface suitable for starting and storing Client
  # instances via DRb.
  class BotManager
    def initialize(client_config_file)
      @clients = {}
      @client_config_file = client_config_file
    end
    
    def client(clientname)
      @clients[clientname] ||= Client.new(@client_config_file)
    end
    
    def shutdown
      @clients.each_value do |client|
        if client && client.running?
          client.quit('bot manager shutting down')
        end
      end
    end
    
    private

  end
  
end