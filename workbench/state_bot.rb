$:.unshift File.expand_path(File.dirname(__FILE__) + "/../lib")

require 'irc/client'
require 'irc/plugin'

include IRC

class BasicPlugin < Plugin
  register_for RPL_WELCOME, CMD_PRIVMSG
  def m001(msg)
    @command_queue.add( JoinCommand.new('#test') )
  end
  def privmsg(msg)
    begin
      if private_message?(msg)
        reply(msg.sender, "what, talking to me in private? begone, coward.")
      else
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
          when /state/
            reply(destination_of(msg), "names: #{@state[:names].inspect}")
            reply(destination_of(msg), "topics: #{@state[:topics].inspect}")
          when /events/
            @state[:events].each do |event|
              reply(destination_of(msg), "event: #{event.inspect}")
            end
          else
            reply(msg, "#{msg.prefix[:nick]}: what?")
          end
        end
      end
    rescue Exception => e
      logger.warn "exception caught: #{e}"
      logger.warn e.backtrace[0]
    end
  end
end

c = Client.new
c.config[:host] = 'f3h.com'
c.config[:nick] = 'bb'
c.config[:username] = 'statebot'
c.config[:realname] = 'basic state-maintaining bot'
c.config[:plugin_dir] = '/Users/nathan/code/irc/plugins'

c.start

trap('INT') { c.quit('caught ctrl+c') }

c.wait_for_quit