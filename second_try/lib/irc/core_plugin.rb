require 'irc/plugin_handler'
include IRC

class CorePlugin < Plugin

  ##### server keepalive #####
  def ping(message)
    message.reply_command(CMD_PONG, message.params[0])    
  end

  ##### JOIN #####
  # two things can happen here. 
  # first, CMD_JOIN is when the server says "ok you joined this channel"
  # second is RPL_TOPIC wherein the server sends the topic for the channel.
  def join(message)
    message.client.channels[ message.params[0] ] = '' # no topic yet
  end

  def m332(message) # RPL_TOPIC
    # should check to see that we're in the channel, but there's no 
    # error handling for this yet otherwise...
    if message.client.channels[ message.params[0] ]
      message.client.channels[ message.params[0] ] = message.params[1]
    end
  end

  ##### NICK HANDLING #####
  # responses resulting from malformed commands are not accounted for
  # since that's out of the scope of this plugin (client shouldn't do bad stuff)
  # potential responses to a NICK command
  # CMD_NICK # server sez nick is coo, this doesn't happen during registration
  # ERR_NONICKNAMEGIVEN # not implemented
  # ERR_ERRONEUSNICKNAME # not implemented (bad nick)
  # ERR_NICKNAMEINUSE # 433
  # ERR_NICKCOLLISION # if this happens, the client probably got booted
  # ERR_UNAVAILRESOURCE # blocked by nick delay (server), out of scope
  # ERR_RESTRICTED # restriction connection, out of scope

  # server acknowledges nick change (OR, watch out, someone *else* changed nicks)
  def nick(message)
    if message.prefix[:nick] == message.client.config[:nick]
      message.client.config[:nick] = message.params[0]
      message.client.config[:oldnick] = nil # tell config that new nick is valid
    end
  end
  
  # the other way the server will validate that our nick is ok during connection
  # is when the server sends an RPL_WELCOME
  def m001(message) # RPL_WELCOME
    # tell config that [:nick] is valid
    # in case nick was changed during initial registration
    message.client.config[:oldnick] = nil 
  end

  # nickname is in use
  def m433(message)
    currentnick = message.client.config[:nick]
    newnick = currentnick + '_'
    # using message.reply_command doesn't do all the necessary bits!
    #message.reply_command(CMD_NICK, newnick)
    message.client.nick(newnick)
  end
  

end

# register the plugin
PluginHandler.register_plugin(CorePlugin, [
  # server keepalive
  CMD_PING,
  # join/topic handling
  CMD_JOIN,
  RPL_TOPIC,
  # nick handling
  CMD_NICK,
  RPL_WELCOME,
  ERR_NICKNAMEINUSE
])