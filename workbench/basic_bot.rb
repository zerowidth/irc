$:.unshift File.expand_path(File.dirname(__FILE__) + "/../lib")

require 'irc/client'
require 'irc/plugin'

include IRC

class BasicPlugin < Plugin
  def m001(msg)
    @command_queue.add( JoinCommand.new('#test') )
  end
  def privmsg(msg)
    begin
      if private_message?(msg)
        reply(msg.sender, "what, talking to me in private? begone, coward.")
      else
        p msg.params[1]
        if msg.params[1] =~ %r{^#{@state[:nick]}(?:\S*\s+)(.*)?}
          case $1
          when /say\s+(.*)/
            reply(destination_of(msg), $1)
          when /do\s+(.*)/
            reply_action(destination_of(msg), $1)
          when /^quit\S*$/
            reply(destination_of(msg), "#{msg.prefix[:nick]}: but why?")
          when /quit\s+(.*)/  
            @command_queue.add QuitCommand.new($1)
          when /join\s+(#\S*)/
            @command_queue.add JoinCommand.new($1)
          when /part\s+(.*)/
            @command_queue.add PartCommand.new($1)
          when /nick\s+(.*)/
            @command_queue.add NickCommand.new($1)
          when /help/
            reply(destination_of(msg), "things i can do: say, do, join, part, quit, help")
          else
            reply(msg, "#{msg.prefix[:nick]}: what?")
          end
        end
      end
    rescue Exception => e
      p e
    end
  end
end
PluginManager.register_plugin BasicPlugin, RPL_WELCOME, CMD_PRIVMSG

c = Client.new
c.config[:host] = 'f3h.com'
c.config[:nick] = 'bb'
c.config[:username] = 'basicbot'
c.config[:realname] = 'basic irc bot'

c.start

trap('INT') { c.quit('caught ctrl+c') }

c.wait_for_quit