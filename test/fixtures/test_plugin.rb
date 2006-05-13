require 'irc/plugin'

include IRC

class TestPlugin < Plugin
  def m332(msg) # rpl_topic
    @command_queue.add( SendCommand.new('reply to topic') )
  end
end