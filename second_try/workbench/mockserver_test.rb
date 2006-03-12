require 'test/unit'
require 'socket'
require 'mockserver'

class TestMockServer < Test::Unit::TestCase
  
  def setup
    @server = MockServer.new(1234) # port 1234
    @server.start
  end
  
  def teardown
    @server.stop # tell the server to quit, if it hasn't already
    @server = nil
  end
  
  # test that a client can send specific data and get a response back using 
  # the mock object to tell it what to do
  def test_basic_server
    @server.mock do |mock|
      # :data and :disconnect (or mock.should_ignore_missing) are required.
      mock.should_receive(:data).with('hows it going').and_return('hello').once
      mock.should_receive(:data).with("hey whats up man").and_return('nothin').once
      mock.should_receive(:disconnect)
      
      s = TCPSocket.new('localhost',1234)
      s.puts('hey whats up man')    
      s.gets # get return value from mock server
      s.puts('hows it going')
      s.gets
      s.close
    end
  end
  
  # test that a server disconnect will drop a connection, and that something else
  # is able to connect and send data afterward
  def test_ordered_session_with_disconnect
    @server.mock do |mock|
      # client closes first connection
      mock.should_receive(:data).with('first').once.ordered
      mock.should_receive(:disconnect).ordered.once
      # server punts second connection
      mock.should_receive(:data).with('second').once.ordered
      
      # put testing code here, including calls to client connects, server discos, etc.
      s = TCPSocket.new('localhost',1234)
      s.puts('first')
      s.close
      s = TCPSocket.new('localhost',1234)
      s.puts('second')
      sleep(0.5) # data won't make it through otherwise...
      
    end

  end
  
  # test that the server sends data back properly
  def test_server_send
    @server.mock do |mock|
      mock.should_ignore_missing
      s = TCPSocket.new('localhost',1234)
      sleep 0.2 # wait for connect, it's not always fast enough
      @server.send_data('hello')
      data = nil
      t = Thread.new {data = s.gets()}
      t.join(1) # in case the blocking call doesn't work, but wait for a sec
      assert_equal "hello\n", data
      s.close
    end
  end

  # test that resetting the server's mock object does, in fact, reset it
  def test_mock_reset
    s = TCPSocket.new('localhost',1234)
    @server.mock do |mock|
      mock.should_receive(:data).once
      s.puts('ping')
      sleep 0.2 # wait for it to get there
    end

    # if the mock isn't reset here, it'll error out when it gets :data again
    @server.reset_mock
        
    @server.mock do |mock|
      mock.should_receive(:data).once
      s.puts('pong')
      sleep 0.2
    end  

  end
  
  # ensure that MockServer#mock can't be run unless the server's been started
  def test_server_must_be_running
    @server.stop
    assert_raise(MockServer::ServerNotRunning) do
      @server.mock {|mock|}
    end
  end
  
  # make sure MockServer's mock object can't be reset while in the middle of 
  # a mock test
  def test_invalid_mock_reset
    assert_raise(MockServer::ResetMockInsideMockBlock) do
      @server.mock do |mock|
        @server.reset_mock
      end
    end
  end
  
  # make sure MockServer#mock can't be called while already inside another
  # MockServer#mock block
  def test_nested_mock
    assert_raise(MockServer::AlreadyInMockBlock) do
      @server.mock do |mock|
        @server.mock do |boom|
          # this is very bad, and this should raise an exception
        end
      end
    end
  end
  
  # this test is to explicitly make sure that, say, a syntax error or any other
  # type of exception caught inside the nested threads in the mock server are 
  # bubbled all the way back up to whomever's running it, so things like
  # mock#method_missing exceptions get caught appropriately in test cases.
  def test_exception_throwing
    # this is TOTALLY wack, and i don't even know if this is kosher at
    # all whatsoever, but what the hell!
    # this replaces the client thread with an exception-thrower!
    # it feels so dirty, but it works :D
    @server.instance_eval do 
      def replace_client_thread_with_evil
        # the sleep is so the server thread has enough time to 
        # loop around and join the client thread again.
        # replacing it immediately will have it die right away,
        # and the server thread will replace it with a new thread without
        # joining up on this one and seeing the exception (server loop time is 0.1)
        @client_thread = Thread.new { sleep 0.2; raise 'foo' }
      end
    end
    assert_raise(RuntimeError) do
      @server.mock do |m|
        sleep 0.2
        @server.replace_client_thread_with_evil
        sleep 0.3 # let the replacement do its work
      end
    end
  end
  
end
