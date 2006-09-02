require 'rubygems'
require 'active_support/core_ext/class/attribute_accessors' # cattr_accessor
require 'socket' # for the exceptions
require 'monitor' # for simulating blocking calls

class SocketStub
  cattr_accessor :server_connected
  attr_accessor :connected, :client_data, :server_data
  def initialize(host, port)
      @host, @port = host, port   
      @client_data = [] # data that this socket writes
      @server_data = [] # data from the simulated server
      @server_data.extend(MonitorMixin)
      @server_cond = @server_data.new_cond
      @connected = false
      raise Errno::ECONNREFUSED unless server_connected
      @connected = true
  end
  def self.open(*args)
    self.new(*args)
  end
  
  def closed?
    !@connected
  end
  
  def close
    @connected = false
    @server_data.synchronize { @server_cond.signal }
  end
  def server_close
    self.server_connected = false
    @client_connected = false
    @server_data.synchronize { @server_cond.signal }
  end

  def gets
    @server_data.synchronize do
      @server_cond.wait
      raise IOError unless server_connected
      data = @server_data.shift
      data
    end
  end
  def puts(data)
    @client_data << data
  end
  
  def server_puts(data)
    if server_connected
      @server_data.synchronize do
        @server_data << data
        @server_cond.signal
      end
    else
      raise 'server not connected!'
    end
  end

  def server_gets
    @client_data.shift # nil if empty
  end
  
end