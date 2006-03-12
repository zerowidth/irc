require 'plugins'
include IRC

class PrivMsg < Plugin
  
  def name
    "privmsg handler"
  end
  
  def privmsg(message) 
  end
  
end

p = PrivMsg.new
Plugins.register_plugin(p,CMD_PRIVMSG)

class Echo < Plugin
  def privmsg(message)
    handle(message)
  end
  def notice(message)
    handle(message)
  end
  def handle(message)
    message.reply(message.sender + ' said to ' + message.receiver + ': '+ message.params[1])
  end
end

p = Echo.new
Plugins.register_plugin(p,CMD_PRIVMSG,CMD_NOTICE)

