require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/connection'
require 'stubs/command_queue_stub'

# this test relies on:
# - command queue stub
# - a functioning DataCommand

class ConnectionTest < Test::Unit::TestCase
  include IRC
  
  TEST_HOST = 'localhost'
  TEST_PORT = 12345
  RETRY_WAIT = 0.5
  
  def setup
    @cq = CommandQueueStub.new # stub so it doesn't rely on actual mutex&stuff implementation
    @conn = IRCConnection.new(TEST_HOST, TEST_PORT, @cq, RETRY_WAIT)
    @server = TCPServer.new(TEST_HOST, TEST_PORT)
    @client = nil # client connection, from server
  end
  
  def teardown
    @conn.disconnect() if @conn.connected?
    @client.close if @client && !@client.closed?
    @server.close if @server && !@server.closed?
  end
  
  # DRY for basic connection & data receiving
  def connect
    t = Thread.new { @client = @server.accept() } # wait for a connection
    @conn.start()
    t.join(0.5) # with a timeout in case something goes wrong
  end
  def gets_from_server
    data = nil # scope
    t = Thread.new { data = @client.gets.strip }
    t.join(0.5) # in case of problems
    data
  end
  
  # tests #############################
  
  def test_basic_connection
    
    # connect
    connect()
    assert @conn.connected?
    
    # check that start() doesn't work twice
    assert_raises RuntimeError do
      @conn.start()
    end
    
    # disconnect
    @conn.disconnect()
    assert_false @conn.connected?
    
    # check that disconnect doesn't work twice
    assert_raises RuntimeError do
      @conn.disconnect()
    end
  end
  
  # test that sending data to the connection results in a DataCommand object in the
  # (stub) CommandQueue
  def test_send_and_receive
    connect()
    
    # greeting from server
    assert_equal 0, @cq.queue.size
    @client.puts('hello')
    sleep(0.5) # wait for @conn to get it

    # check that the command queue has a new DataCommand on it
    assert_equal 1, @cq.queue.size
    
    # reply to server
    @conn.send('greetings')
    assert_equal 'greetings', gets_from_server()
    
  end
  
  def test_reconnect
    connect()
    assert @conn.connected?
    
    # make sure it's working
    @conn.send('hello')
    assert 'hello', gets_from_server()

    # kill the server-side connection
    @client.close()
    
    # wait for the reconnect
    t = Thread.new { @client = @server.accept() } # wait for another connection
    t.join(RETRY_WAIT*2) # wait for twice the retry interval
    
    assert_false @client.closed?
    assert @conn.connected?

    # make sure it works again
    @conn.send('hello')
    assert_equal 'hello', gets_from_server()   
    
  end
  
end