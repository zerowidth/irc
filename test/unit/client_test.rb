require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/client'

class ClientTest < Test::Unit::TestCase
  include IRC
  
  TEST_HOST = 'localhost'
  TEST_PORT = 12345
  RETRY_WAIT = 0.5
  
  # override the class to make it more transparent for testing
  class IRC::Client
    attr_reader :state, :plugin_manager, :connection, :queue_thread
  end
  # same for CommandQueue
  class IRC::CommandQueue
    attr_reader :q
  end
  
  def setup
    # create client
    @client = Client.new
    
    # basic configuration for easier testing
    @client.config[:nick] = 'nick'
    @client.config[:realname] = 'realname'
    @client.config[:user] = 'user'
    
    # "remote server"
    @clientthread = nil # since call to @client.start doesn't return
    @server = TCPServer.new(TEST_HOST, TEST_PORT)
    @serverclient = nil # client connection, from server
  end

  def teardown
    # clean up
    @clientthread.kill if @clientthread && !@clientthread.alive?
    @serverclient.close if @serverclient && !@serverclient.closed?
    @server.close if @server && !@server.closed?
  end
  
  def test_config_required_before_start
    assert_raise Config::ConfigOptionRequired do
      @client.start()
    end
  end
  
  def test_config_readonly_while_running
    assert_false @client.config.readonly?
    config_client()
    @client.start()
    assert @client.config.readonly?, "config should be readonly"
    @client.quit()
    assert_false @client.config.readonly?, "config should be writeable"
  end
  
  def test_cant_start_client_twice
    config_client()
    @client.start
    assert_raise RuntimeError do
      @client.start()
    end
  end
  
  def test_cant_stop_client_twice
    config_client()
    @client.start()
    @client.quit() # first quit
    assert_raise RuntimeError do
      @client.quit() # second quit
    end
  end
  
  def test_connection
    client_connect()
    assert @serverclient, "client should have connected, but didn't"
    assert @client.connection.connected?, "client should be connected"
  end
  
  def test_client_can_connect_twice
    client_connect()
    @client.quit()
    # make sure it's quit
    assert_false @client.connection.connected?, 'client should have disconnected'
    # now make sure the client can connect a second time
    test_connection()
  end
    
  def test_register_on_connect
    client_connect()
    assert_equal 'USER user 0 * :realname', gets_from_server
    assert_equal 'NICK nick', gets_from_server
  end

  def test_quit_sends_quit_message
    client_connect()
    2.times { assert gets_from_server } # clear the registration out of the way
    @client.quit('quitting')
    assert_equal 'QUIT :quitting', gets_from_server
  end
  
  # tests for refactoring -- changing start() from a blocking call to a nonblocking call,
  # and adding the #wait_for_quit() method
  def test_start_returns
    config_client()
    t = Thread.new { @client.start() }
    t.join(0.5) # give it half a second
    assert_false t.alive? # thread should be dead!
  end
  
  def test_wait_for_quit
    config_client()
    @client.start()
    t = Thread.new { @client.wait_for_quit() }
    t.join(0.01) # catch exceptions
    assert t.alive?
    @client.quit()
    t.join(0.5) # wait for quit, this should return and the thread should die
    assert_false t.alive?, 'client wait should have returned'
  end
    
  # helpers
  def config_client
    @client.config[:host] = TEST_HOST
    @client.config[:port] = TEST_PORT
    @client.config[:retry_wait] = RETRY_WAIT    
  end
  
  def client_connect
    config_client()
    t = Thread.new { @serverclient = @server.accept() } # wait for a connection
    @client.start()
    t.join(0.5) # with a timeout in case something goes wrong
  end
  
  def gets_from_server
    data = nil # scope
    t = Thread.new { data = @serverclient.gets.strip }
    t.join(0.1) # in case of problems
    data
  end
  
  
end