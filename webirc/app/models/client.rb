require 'drb'

class Client

  cattr_accessor :drb_uri # set this in environment.rb
  
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
    return events if events.first.id > id # easy case, first event in the queue is newer than anything we've seen
    events.find_all {|event| event.id > id}
  end
  
  def connected?
    @manager.client_running? @client_name
  end
  
  # establish a connection (or try to) using the connection details.
  def connect(connection)
    @manager.merge_config @client_name, connection.to_hash
    @manager.start_client @client_name
  end
  
  def shutdown
    @manager.shutdown(@client_name)
  end
  
  def add_event(event)
    @manager.add_event @client_name, event
  end
  
  def add_command(command)
    @manager.add_command @client_name, command
  end

end
