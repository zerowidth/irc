require 'plugins'

class WelcomeTest < Plugin
  def m001(m)
puts "I feel so welcome!"
  end
end

w = WelcomeTest.new
Plugins.register_plugin(w,RPL_WELCOME)

class InvalidNickHandler < Plugin
  def m433(m)
    @client.set_new_nick(@client.config.nick+'_')
  end
end

inh = InvalidNickHandler.new
Plugins.register_plugin(inh,ERR_NICKNAMEINUSE)

class AuthCommands < Plugin
  def privmsg(m)
    if m.private?
      msg = m.params[1]
      admin, pass, command = msg.split(/\s+/,3)
      if admin=='admin' && pass==@client.config.admin_pass
        do_command(command)
      elsif admin=='admin' && pass=='help' && !command # in case password is 'help' :P
        
      end
    end
  end
  def help
  
  end
  private 
  def do_command(command)
    case command
    when 'reload plugins'
      @client.reload_plugins
    when /quit(?:\s+(.*))?/
      @client.quit($1)
    end
  end
end
ac = AuthCommands.new
Plugins.register_plugin(ac,CMD_PRIVMSG)

class Surprised < Plugin
  def surprise(message)
    message.reply "HOLY SHIT I'M SURPRISED"
  end
  def little_surprise(message)
    message.reply('eep!')
  end
  def boo(message)
    message.reply("BOO!")
  end
end
s = Surprised.new
Plugins.register_command(s,'!!',false,'surprise')
Plugins.register_command(s,'',false,'little_surprise')
Plugins.register_command(s,'boo')

class Sleeper < Plugin
  def sleep(message, command, args)
    time = 5
    time = args.to_f if args.to_f != 0.0
    message.reply("sleeping for #{time} seconds")
    Kernel.sleep(time)
    message.reply("k i'm awake after sleeping for #{time}")
  end
end
sleeper = Sleeper.new
Plugins.register_command(sleeper,'sleep')