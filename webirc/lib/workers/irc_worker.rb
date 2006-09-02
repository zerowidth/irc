require 'irc/client'
require 'irc/plugins/state_manager' # so we get events!
require 'models/connection_pref'

class IrcWorker < BackgrounDRb::Rails
  
  def do_work(config_hash)
    IRC::Client.logger = BACKGROUNDRB_LOGGER
    @client = IRC::Client.new
    @client.merge_config config_hash
  end

  def start
    @client.start
  end
  
  def quit(reason=nil)
    @client.quit(reason)
  end
  
  def connected?
    @client && @client.connected?
  end
  
  def events
    @client.state[:events] if @client and @client.state
  end
  
  def events_since(last_id)
    last_id ||= 0
    events.find_all {|event| event.id > last_id}
  end
  
  def state
    @client.state
  end
  
  def autojoin(chan)
    @client.state[:topics] ||= {}
    @client.state[:topics][chan] = '' # will be picked up by state manager for autojoining    
  end
  
  def add_event(event)
    @client.state[:events] << event    
  end
  
  def change_nick(newnick = '')
    @client.change_nick(newnick)
  end
  
  def channel_message(chan, msg)
    @client.channel_message(chan, msg)
    add_event IRC::ChannelMessageEvent.new( :who => state[:nick], :where => chan, :what => msg, :context => :self )
  end

end
