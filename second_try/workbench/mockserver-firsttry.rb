require 'test/unit'
require 'socket'

class UnitTest < Test::Unit::TestCase
  
  def setup
    @server = TestMockServer.new(1234) # localhost:1234
  end
  
  def teardown
    @server.shutdown # tell the server to quit, if it hasn't already
  end
  
  def test_basic_server
    @server.start
    s = TCPSocket.new('localhost',1234)
    s.puts('hey whats up man')
    s.puts('hows it going')
    s.close
    @server.shutdown
    p @server.get_mock # this will be empty if @server.shutdown hasn't been called yet
  end
  
end

class TestMockServer
  
  def initialize(port)
    @server = TCPServer.new('localhost',port)
    @recorder = []
    @server_thread = nil
  end

  def start
    @server_thread = Thread.new do
      sock = @server.accept
      while data = sock.gets # returns nil if socket is closed
        @recorder << data
      end
    end
  end
  
  def shutdown
    if @server_thread
      # wait for up to a second for thread processing
      @server_thread.join(1)
      @server_thread.kill
      @server_thread = nil
    end
  end

  # replace @recorder with a mock object
  # add methods to set the mock object's expected strings and responses
  
  # using an array of strings for demo purposes.
  def get_mock
    @recorder
  end
  
end