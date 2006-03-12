require 'irc/command'
require 'irc/message'
require 'irc/rfc2812'

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
  attr_reader :data # for easy access (not critical)

  def initialize(data)
    @data = data
  end
  
  def execute(connection)
    connection.send(@data)
  end
end

# RegisterCommand: (attempts to) register the client on the network
class RegisterCommand < IRCCommand
  type :uses_queue
  
  def initialize(nick,user,realname)
    @nick = nick
    @user = user
    @realname = realname
  end
  
  def execute(queue)
    # ENHANCEMENT: add PASSWORD command
    queue.add SendCommand.new("USER #{@user} 0 * :#{@realname}")
    queue.add NickCommand.new(@nick)
  end
end

# NickCommand: sends nick change message
class NickCommand < IRCCommand
  type :uses_queue
  def initialize(nick)
    @nick = nick
  end
  def execute(queue)
    queue.add SendCommand.new("NICK #{@nick}")
  end
end

end # module