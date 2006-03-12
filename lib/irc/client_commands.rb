require 'irc/command'
require 'irc/message'

module IRC

# DataCommand: contains text data coming in from the network
class DataCommand < IRCCommand
  type :uses_plugins

  def initialize(data)
    @data = data
  end
  
  def execute(plugin_handler)
    msg = Message.new(@data)
    plugin_handler.dispatch(msg)
  end
  
end

# SendCommand: contains text data to send over the network
class SendCommand < IRCCommand
  type :uses_socket

  def initialize(data)
    @data = data
  end
  
  def execute(connection)
    connection.send(@data)
  end
end


  
end # module