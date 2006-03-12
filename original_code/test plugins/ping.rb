require 'plugins'
include IRC

class Ping < Plugin
  # for server/client keepalive
  def ping(message)
    message.reply_command(CMD_PONG,message.params[0])
  end
  def msgping(message,command,args)
    message.reply('pong: '+message.sender+' '+message.receiver)
  end
end

p = Ping.new
Plugins.register_plugin(p,CMD_PING)
Plugins.register_command(p,'ping',false,'msgping')