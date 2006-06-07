require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/client'

class ClientTest < Test::Unit::TestCase
  include IRC
  
  TEST_HOST = 'localhost'
  TEST_PORT = 12345
  RETRY_WAIT = 0.5
  
  # override the class to make it more transparent for testing
  class IRC::Client
    attr_reader :plugin_manager, :connection # make the basics accessible
    attr_reader :queue_thread # make queue and quit flag accessible
    attr_reader :data_queue # internal data queue
    def set_quit; @quit = true; end # this is highly implementation-related!
  end
  # and same for PluginManager, for testing loading of the core plugin
  class IRC::PluginManager
    attr_reader :plugins
  end
  class IRC::IRCConnection
    attr_reader :command_queue
  end
  
  # set up some test commands for testing command execution
  module ExecutionRecorder
    attr_reader :params
    def initialize
      @params = []
    end
    def execute(*args)
      @params = args
    end
  end
  
  class TestClientCommand < IRC::ClientCommand; include ExecutionRecorder; end
  class TestSocketCommand < IRC::SocketCommand; include ExecutionRecorder; end
  class TestPluginCommand < IRC::PluginCommand; include ExecutionRecorder; end
  class TestQueueCommand < IRC::QueueCommand; include ExecutionRecorder; end
  class TestQueueConfigStateCommand < IRC::QueueConfigStateCommand
    include ExecutionRecorder;
  end
  class TestSleepCommand < IRC::ClientCommand
    def execute
      sleep(0.5)
    end
  end
  class TestTimedCommand < IRC::ClientCommand
    attr_reader :time
    def execute
      time = Time.now
    end
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
      @client.start
    end
  end
  
  def test_config_readonly_while_running
    assert_false @client.config.readonly?
    config_client
    @client.start
    assert @client.config.readonly?, "config should be readonly"
    @client.quit
    assert_false @client.config.readonly?, "config should be writeable"
  end
  
  def test_cant_start_client_twice
    config_client
    @client.start
    assert_raise RuntimeError do
      @client.start
    end
  end
  
  def test_cant_stop_client_twice
    config_client
    @client.start
    @client.quit # first quit
    assert_raise RuntimeError do
      @client.quit # second quit
    end
  end
  
  def test_connection
    client_connect
    assert @serverclient, "client should have connected, but didn't"
    assert @client.connection.connected?, "client should be connected"
  end
  
  def test_client_can_connect_twice
    client_connect
    @client.quit
    # make sure it's quit
    assert_false @client.connection.connected?, 'client should have disconnected'
    # now make sure the client can connect a second time
    test_connection
  end
    
  def test_register_on_connect
    client_connect
    assert_equal 'USER user 0 * :realname', gets_from_server
    assert_equal 'NICK nick', gets_from_server
  end
  
  # this one is fun. when QuitCommand was being executed, it tells client to quit.
  # before it sends any data, it kills the queue thread, which is what's executing
  # the quit command... whoops!
  def test_quit
    client_connect
    2.times { assert gets_from_server } # clear registration
    @client.command_queue << QuitCommand.new('reason')
    assert_equal 'QUIT :reason', gets_from_server
    assert_false @client.connection.connected?
  end
  
  # tests for refactoring -- changing start from a blocking call to a nonblocking call,
  # and adding the #wait_for_quit method
  def test_start_returns
    config_client
    t = Thread.new { @client.start }
    t.join(0.5) # give it half a second
    assert_false t.alive? # thread should be dead!
  end
  
  def test_wait_for_quit
    config_client
    @client.start
    t = Thread.new { @client.wait_for_quit }
    t.join(0.01) # catch exceptions
    assert t.alive?
    @client.quit
    t.join(0.5) # wait for quit, this should return and the thread should die
    assert_false t.alive?, 'client wait should have returned'
  end

  def test_reconnect
    client_connect
    2.times { assert gets_from_server } # clear the registration
    assert @client.connection.connected?
    assert_false @serverclient.closed?
    @client.reconnect
    assert @client.connection.connected?
    assert_equal nil, @serverclient.gets # connection should have been closed
    server_accept # get the new connection
    assert_false @serverclient.closed?
  end

  # test that the client correctly executes commands based on their type.
  # This tests that the client grabs the commands off the queue and that they
  # also get executed correctly.
  
  def test_client_command_execution
    cmd = TestClientCommand.new
    execute_with_client cmd
    assert_equal 1, cmd.params.size
    assert_equal @client, cmd.params[0]
  end
  
  def test_socket_command_execution
    cmd = TestSocketCommand.new
    execute_with_client cmd
    assert_equal 1, cmd.params.size
    assert_equal @client.connection, cmd.params[0]
  end
  
  def test_plugins_command_execution
    cmd = TestPluginCommand.new
    execute_with_client cmd
    assert_equal 1, cmd.params.size
    assert_equal @client.plugin_manager, cmd.params[0]
  end
  
  def test_queue_command_execution
    cmd = TestQueueCommand.new
    execute_with_client cmd
    assert_equal 1, cmd.params.size
    assert_equal @client.data_queue, cmd.params[0], 'should be executed with data queue'
  end
  
  def test_queue_config_state_command_execution
    cmd = TestQueueConfigStateCommand.new
    execute_with_client cmd
    assert_equal 3, cmd.params.size
    assert_equal @client.data_queue, cmd.params[0], 'should be executed with data queue'
    assert_equal @client.config, cmd.params[1]
    assert_equal @client.state, cmd.params[2]
  end
  
  # core plugin and other plugin loading tests

  def test_core_plugin_registered
    client_connect # start everything up, so plugin manager is instantiated
    assert @client.plugin_manager.plugins.size > 0, 'no plugins registered with plugin manager'
    assert CorePlugin, @client.plugin_manager.plugins.first.class
  end
  
  # config load from file test, this is a refactoring to change Client.new to 
  # accept a config filename as an optional parameter
  
  def test_client_loads_config_from_file
    @client = Client.new('test/fixtures/config.yaml')
    assert_equal 10000, @client.config[:port]
  end
  
  # this method was added later ... utility method!
  def test_is_running
    assert_equal false, @client.running?, 'client should not be running'
    client_connect
    assert_equal true, @client.running?, 'client should be running'
    @client.quit
    assert_equal false, @client.running?, 'client should not be running'
  end
  
  # ----- refactoring for two internal queues instead of one
  def test_data_queue_exists
    assert @client.command_queue
    assert @client.data_queue
  end
  
  def test_socket_sends_to_data_queue
    client_connect
    assert @client.queue_thread.alive?, 'queue thread should be running'
    @client.queue_thread.kill # now nothing will empty the queues
    @serverclient.puts('lol')
    sleep(0.3) # wait for it...
    assert @client.command_queue.empty?, 'command queue should be empty'
    assert_false @client.data_queue.empty?, 'data queue should have something in it!'
    # check the contents of the queue
    assert @client.data_queue.pop(true).kind_of?(RegisterCommand), 'there should be a register command here'
    assert @client.data_queue.pop(true).kind_of?(DataCommand), 'there should be a data command here'
  end
  
  def test_command_queue_gets_used
    # no explicit test needed here, since it's made implicit by the use of
    # command queue in the execute_with_client helper below, and elsewhere
  end

  def test_client_queue_emptied_after_connection_successful
    # also not needed, it's implicit in the execute_with_client helper
  end
  
  def test_auto_reconnect
    client_connect
#    sleep(0.05) # wait for things to settle
    @serverclient.close
    t = Thread.new { @serverclient = @server.accept }
    t.join(RETRY_WAIT*2) # wait for twice the retry interval
    assert_false @serverclient.closed?, 'server should have received reconnection!'
    assert @client.running?, 'client should have reconnected!'
  end

  # helpers ###########################
  def config_client
    @client.config[:host] = TEST_HOST
    @client.config[:port] = TEST_PORT
    @client.config[:retry_wait] = RETRY_WAIT    
    @client.config[:auto_reconnect] = true
  end
  
  def client_connect
    config_client
    server_accept do
      @client.start
    end
  end
  
  def server_accept
    t = Thread.new { @serverclient = @server.accept } # wait for a connection
    yield if block_given?
    t.join(0.5) # with timeout in case of problems
  end
  
  def gets_from_server
    data = nil # scope
    t = Thread.new { data = @serverclient.gets }
    t.join(0.1) # in case of problems
    data.strip! if data
    data
  end
  
  # test helper
  # puts cmd in the client's queue and waits for it to be executed.
  def execute_with_client(cmd)
    client_connect

    # this might be a race condition, the queue thread might not have checked @quit already.
    # If this whole test fails, check that the queue thread isn't dead yet
    @client.queue_thread.join(0.05) # try to avoid race condition by waiting a tiny bit
    @client.set_quit # set the flag after the thread's waiting on the queue
    
    assert @client.queue_thread.alive?, 'race condition encountered, please check'

    @client.command_queue << cmd

    # there's also another race condition here, one involving scheduling. even if the above
    # is successful, it's possible that the queue thread quits out before anything
    # is added to the command queue. if this happens, the command will not be executed
    
    # join the queue thread for awhile to make sure the command gets executed.
    # since @quit is set, it should stop after processing the command, aka immediately.
    @client.queue_thread.join(0.2) # catches the exception
    assert @client.command_queue.empty?, 'uh oh, command queue should be empty. are things being transferred?'
    assert_false @client.queue_thread.alive?, "check queue thread quit flag, something's wrong"
  end
  
end