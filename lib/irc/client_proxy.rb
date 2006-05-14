=begin
The ClientProxy object sets up a convenient interface for applications (rails) to use
when serving Client instances via the bot manager / over DRb. 
I'd prefer to serve Client instances directly, but the way DRb serializes objects
prevents this. For example, some_client.state yields a hash which is serialized, sent
across the wire, and instantiated locally and thus changes made to this hash aren't 
sent back to the actual instance.
This could theoretically be worked around by ensuring *nothing* gets serialized, perhaps
by including DRbUndumped in, say, Object, but that seems like a high-level introduction of pain...
and also Events and the like still need to be serialized. 

So anyway: skip all of that, and set up a ClientProxy object that gets served up by 
the bot manager. The bot manager handles instantiation and configuration.

ClientProxy provides indirect access to:
- event queue
  - add_event
  - get_events
- command queue
  - add_command
- state
  - state() # ?
  - state() = # ?
=end 

require 'drb'

module IRC
  
class ClientProxy
  
  include DRbUndumped # proxy object only please
  
  def initialize(client)
    @client = client    
  end
  
  # pass some method calls straight on through to the client
  def method_missing(symbol, *args)
    if [:start, :running?, :quit].include? symbol
      @client.send symbol, *args
    else
      super
    end
  end
  
  # key is required, otherwise the events would get passed through
  # every time this was called, and that could be a lot of data
  def state(key)
    @client.state ? @client.state[key] : nil
  end
  
  def config(key)
    @client.config[key]
  end
  
  def merge_config(configdata)
    @client.config.merge!(configdata)
  end
  
  def events
    if @client.state && @client.state[:events]
      @client.state[:events]
    else
      []
    end
  end
  
  def add_event(event)
    return unless @client.running? # state won't apply otherwise
    @client.state[:events] ||= [] # just in case
    @client.state[:events] << event
  end
  
  def add_command(command)
    @client.command_queue << command
  end


end
end # module