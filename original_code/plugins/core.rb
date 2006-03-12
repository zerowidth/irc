require 'plugins'
include IRC

# for server/client keepalive
class Ping < Plugin
  def ping(message)
    message.reply_command(CMD_PONG,message.params[0])
  end
end

class InvalidNickHandler < Plugin
  def m433(m)
    @client.set_new_nick(@client.config.nick+'_')
  end
end

class Admin < Plugin
  def admin(message, command, args)
    pass, cmd, arg = args.split(/\s+/,3)
    return unless pass == @client.config.admin_pass
    
    case cmd
    when 'reload'
      @client.reload_plugins if arg == 'plugins'
    when 'join'
#      @client.join_channel(arg) if arg && arg.length > 0
    when 'part'
#      @client.part_channel(arg) if arg && arg.length > 0
    when 'quit'
      @client.quit(arg)
    when 'raw'
      @client.send_raw(arg)
    end
  end
end

p = Ping.new
Plugins.register_plugin(p,CMD_PING)

inh = InvalidNickHandler.new
Plugins.register_plugin(inh,ERR_NICKNAMEINUSE)

a = Admin.new
Plugins.register_command(a,'admin',true) # private only