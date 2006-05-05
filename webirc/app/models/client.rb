require 'drb'

class Client

  cattr_accessor :drb_uri
  
  attr_accessor :client_name

  # this will connect to a DRb server and perform operations against a client.
  def initialize client_name
    @client_name = client_name
    @manager = DRbObject.new_with_uri drb_uri
  end
  
  def events
    @manager.get_events(@client_name)
  end

  def events_since id
    # i don't quite like this: it dumps a lot of data across the network every time
    # this could definitely be optimized.
    # TODO improve this interface with the client/manager to retrieve events since a certain id
    events = @manager.get_events(@client_name)
    return events if events.last.id < id # easy case
    events.find_all {|event| event.id > id}
  end

end
