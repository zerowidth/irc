require 'irc/command'
require 'irc/message'
require 'irc/rfc2812'

module IRC

# DataCommand: contains text data coming in from the network
class DataCommand < PluginCommand
  def initialize(data)
    @data = data
  end
  def execute(plugin_handler)
    msg = Message.parse(@data)
    plugin_handler.dispatch(msg)
  end
  
end

# SendCommand: contains text data to send over the network
class SendCommand < SocketCommand
  def initialize(data)
    @data = data
  end
  
  def execute(connection)
    connection.send(@data)
  end
end

# QuitCommand: tells client to quit (with optional reason)
class QuitCommand < ClientCommand  
  def initialize(reason=nil)
    @reason = reason
  end
    
  def execute(client)
    client.quit(@reason)
  end
end

class ReconnectCommand < ClientCommand
  def execute(client)
    client.reconnect
  end
end   

# RegisterCommand: (attempts to) register the client on the network
class RegisterCommand < QueueCommand
  def initialize(nick,user,realname)
    @nick = nick
    @user = user
    @realname = realname
  end
  
  def execute(queue)
    # ENHANCEMENT: add PASSWORD command
    queue << SendCommand.new("USER #{@user} 0 * :#{@realname}")
    queue << NickCommand.new(@nick)
  end
end

# NickCommand: sends nick change message
class NickCommand < QueueConfigStateCommand
  def initialize(nick)
    @nick = nick
  end
  
  def execute(queue,config,state)
    queue << SendCommand.new(CMD_NICK + ' ' + @nick)
    # save the new nick, but don't change the existing nick until the server
    # sends a response back saying it was successful (this is handled elsewhere).
    # yes, this clobbers any existing newnick. if a nick command is executed several times
    # in a row, the last one should apply to any "nick is OK" responses (also handled elsewhere)
    state[:newnick] ||= []
    state[:newnick] << @nick 
  end
end

class JoinCommand < QueueCommand
  simple_queue_command CMD_JOIN
end

class PartCommand < QueueCommand
  simple_queue_command CMD_PART
end

end # module