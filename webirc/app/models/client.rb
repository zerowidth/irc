require 'drb'

class Client

  cattr_accessor :drb_uri # set this in environment.rb
  
#  attr_accessor :client_name

  # Client.for(some_user)
  def self.for(user)
#    manager = DRbObject.new_with_uri drb_uri
    Client.new user.id
  end

  # this will connect to a DRb server and retrieve a client proxy object
  def initialize client_name
    @client_name = client_name
    @manager = DRbObject.new_with_uri drb_uri
    @client = @manager.client client_name
  end
  
  def state(key)
    @client.state(key)
  end
  
  def events
    @client.events
  end

  def events_since id
    # i don't quite like this: it dumps a lot of data across the network every time
    # this could definitely be optimized.
    # TODO improve this interface with the client/manager to retrieve events since a certain id
    id ? events.find_all {|event| event.id > id} : events
  end
  
  def connected?
    @client.running?
  end
  
  # establish a connection (or try to) using the connection details.
  def connect(connection)
    @client.merge_config connection.to_hash
    @client.start
  end
  
  def quit(reason = nil)
    @client.quit reason
    @manager.remove_client(@client_name)
  end
  
  def add_event(event)
    @client.add_event event
  end
  
  def add_command(command)
    @client.add_command command
  end

end
