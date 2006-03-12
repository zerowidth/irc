$:.unshift File.expand_path(File.dirname(__FILE__) + "/lib")
require 'irc/client'

include IRC
class DRbClient < Client
  
end

class PingPlugin < Plugin
  def privmsg(msg)
    case msg.params[1]
      when /^!quit((\s+)(.*))?/
        msg.client.quit($2 || 'bye bye now')
      when /^!ping/
        msg.reply("pong #{msg.sender} #{msg.receiver}")
      when /^!say\s+(.*)/
        msg.reply("#{$1}")
      when /^!nick\s+(.*)/
        msg.client.nick($1)
      when /^!join\s+(.*)/
        msg.client.join($1)
      when /^!part((?:\s+).*$)?/
        if $1
          msg.client.part($1)
        elsif !msg.private?
          msg.client.part(msg.params[0])
        end
    end
  end
end
PluginHandler.register_plugin(PingPlugin, CMD_PRIVMSG)

if __FILE__ == $0

#set_trace_func proc { |event, file, line, id, binding, classname|
#  printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname
#}


IRC::LOGGING = true
dc = DRbClient.new
dc.config[:host] = 'f3h.com'
dc.config[:nick] = 'rb'

puts "starting client"
t = Thread.new do 
  dc.start

end
sleep(2)
dc.join('#test')
t.join
dc.shutdown
sleep(1)


end