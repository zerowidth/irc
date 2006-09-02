require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'irc/connection'

class ConnectionTest < Test::Unit::TestCase
  include IRC
  
  def setup
    SocketStub.server_connected = true
    @conn = Connection.new(TEST_HOST, TEST_PORT)
    @server = TCPServer.new(TEST_HOST, TEST_PORT)
  end
  
  def teardown
    @conn.disconnect if @conn.connected?
    @client.close if @client && !@client.closed?
    if @server && !@server.closed?
      @server.close 
    end
  end

  def connect
    assert @client.nil?, 'client should be nil!'
    @conn.connect
#    @client = @server.accept
  end

  # def gets_from_server
  #   data = nil # scope
  #   t = Thread.new { data = @client.gets.strip }
  #   t.join(0.5) # in case of problems
  #   data
  # end
  
  # tests #############################
  
  def test_basic_connection
    connect
    assert @conn.connected?, 'should be connected'
    # check that start doesn't work twice
    assert_raises RuntimeError do
      @conn.connect
    end
    
    # disconnect
    @conn.disconnect
    assert_false @conn.connected?

  end
  
  def test_send
    connect
    @conn.send('greetings')
    assert_equal 'greetings', @conn.socket.server_gets #gets_from_server
  end
  
  def test_connect_disconnect_callbacks
    # data not included here because the disconnect happens too soon
    assert_callbacks @conn, :connected, :disconnected do
      connect
      @conn.disconnect
    end
  end
  
  def test_server_disconnected_callback
    connect
    assert_callbacks @conn, :disconnected do
      @conn.socket.server_close # @client.close # kill the connection from the server side
      @conn.connection_thread.join(1) # wait a second for the dispatch to go out
    end
  end
  
  def test_data_callback
    connect
    assert_callbacks @conn, [:data, 'lol'] do
      @conn.set_disconnect
      @conn.socket.server_puts 'lol'
      @conn.connection_thread.join(1) # wait for the client to process the socket send
    end
  end
  
  def test_connection_with_exception
    SocketStub.server_connected = false
    recorder = CallbackRecorder.new(:connection_error)
    recorder.respond_to? :connection_error
    recorder.connection_error()
    @conn.add_observer recorder, :connection_error
    connect
    wait_for_callback_dispatch @conn
    assert_equal :connection_error, recorder.calls.first
    assert recorder.calls[1][1].is_a? Errno::ECONNREFUSED
  end
  
  def test_wait_for_disconnect
    connect
    t = Thread.new { @conn.wait_for_disconnect }
    t.join(0)
    assert t.alive?, 'should still be alive'
    @conn.disconnect
    t.join(0.5) # wait for it
    assert_false t.alive?
  end

end