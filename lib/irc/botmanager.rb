require 'irc/client'
require 'drb'

module IRC
  # BotMaster provides an interface suitable for starting and storing Client
  # instances via DRb.
  class BotManager

    include DRb::DRbUndumped

    def initialize(client_config_file)
      @clients = {}
      @client_config_file = client_config_file # base config for all Clients
    end
    
    def start_client(client_name)
      get_client(client_name).start
    end
    
    def client_running?(client_name)
      get_client(client_name).running?
    end
    
    def merge_config(client_name, configdata)
      get_client(client_name).config.merge!(configdata)
    end
    
    def get_events(client_name)
      client = get_client(client_name)
      if client.state && client.state[:events]
        client.state[:events]
      else
        []
      end
    end
    
    def add_event(client_name, event)
      client = get_client(client_name)
      return unless client.running? # state won't apply otherwise
      client.state[:events] ||= [] # just in case
      client.state[:events] << event
    end
    
    def add_command(client_name, command)
      get_client(client_name).command_queue << command
    end
      
    def shutdown(client_name = nil)
      msg = 'bot manager shutting down'
      if client_name
        @clients[client_name].quit(msg) if @clients[client_name] and @clients[client_name].running?
      else # quit all
        @clients.each_value do |client|
          if client and client.running?
            client.quit msg
          end
        end
      end # if
    end
    
    private
    
    def get_client(client_name)
      @clients[client_name] ||= Client.new(@client_config_file)
    end
    
  end
  
end