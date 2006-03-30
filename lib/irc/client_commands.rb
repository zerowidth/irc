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

  def initialize(data)
    @data = data
  end
  
  def execute(connection)
    connection.send(@data)
  end
end

# QuitCommand: tells client to quit (with optional reason)
class QuitCommand < IRCCommand
  type :uses_client
  
  def initialize(reason=nil)
    @reason = reason
  end
    
  def execute(client)
    client.quit(@reason)
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
  type :uses_queue_config_state # uses the queue and the state
  
  def initialize(nick)
    @nick = nick
  end
  
  def execute(queue,config,state)
    queue.add SendCommand.new(CMD_NICK + ' ' + @nick)
    # save the new nick, but don't change the existing nick until the server
    # sends a response back saying it was successful (this is handled elsewhere).
    # yes, this clobbers any existing newnick. if a nick command is executed several times
    # in a row, the last one should apply to any "nick is OK" responses (also handled elsewhere)
    state[:newnick] ||= []
    state[:newnick] << @nick 
  end
end

class JoinCommand < IRCCommand
  queue_command CMD_JOIN
end

class PartCommand < IRCCommand
  queue_command CMD_PART
end

end # module