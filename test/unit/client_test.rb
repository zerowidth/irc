require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/client'
require 'mocks/command_mock' # mock command for command execution testing

class ClientTest < Test::Unit::TestCase
  include IRC
  
  TEST_HOST = 'localhost'
  TEST_PORT = 12345
  RETRY_WAIT = 0.5
  
  # override the class to make it more transparent for testing
  class IRC::Client
    attr_reader :state, :plugin_manager, :connection, :command_queue # make the basics accessible
    attr_reader :queue_thread # make queue and quit flag accessible
    def set_quit; @quit = true; end # this is highly implementation-related!
  end
  # same for CommandQueue
  class IRC::CommandQueue
    attr_reader :q
  end
  # same for PluginManager, for testing loading of the core plugin
  class IRC::PluginManager
    attr_reader :plugins
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
  
  # this one is fun. when QuitCommand was being executed, it tells client to quit.
  # before it sends any data, it kills the queue thread, which is what's executing
  # the quit command... whoops!
  def test_quit_command_sends_message
    client_connect()
    2.times { assert gets_from_server } # clear registration
    @client.command_queue.add QuitCommand.new('reason')
    assert_equal 'QUIT :reason', gets_from_server
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

  # test that the client correctly executes commands based on their type.
  # This tests that the client grabs the commands off the queue and that they
  # also get executed correctly.
  def test_client_command_execution
    client_connect()
    command_type_test(:uses_client, @client)
  end
  
  def test_socket_command_execution
    client_connect()
    command_type_test(:uses_socket, @client.connection)
  end
  
  def test_plugins_command_execution
    client_connect()
    command_type_test(:uses_plugins, @client.plugin_manager)
  end
  
  def test_queue_command_execution
    client_connect()
    command_type_test(:uses_queue, @client.command_queue)
  end
  
  def test_queue_config_state_command_execution
    client_connect()
    command_type_test(:uses_queue_config_state, @client.command_queue, @client.config, @client.state)
  end
  
  # core plugin and other plugin loading tests

  def test_core_plugin_registered
    client_connect() # start everything up, so plugin manager is instantiated
    assert @client.plugin_manager.plugins.size > 0, 'no plugins registered with plugin manager'
    assert CorePlugin, @client.plugin_manager.plugins.first.class
  end

  # helpers ###########################
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
  
  # tests that a command of type command_type has execute() invoked with execute_called_with
  def command_type_test(command_type, *execute_called_with)
    # this might be a race condition, the queue thread might not have checked @quit already.
    # If this whole test fails, check that the queue thread isn't dead yet
    @client.queue_thread.join(0.05) # try to avoid race condition by waiting a tiny bit
    @client.set_quit # set the flag after the thread's waiting on the queue
    
    # there's also another race condition here, one involving scheduling. even if the above
    # is successful, it's possible that the queue thread quits out before anything
    # is added to the command queue. if this happens, the .type() call will not be called.

    CommandMock.use('mock command') do |cmd|
      # make sure the command is executed with the correct arguments
      cmd.should_receive(:execute).with(*execute_called_with).once # execute only once!
      # placed second, since it's evaluated first (yay flexmock) (checking for race condition)
      # if this fails, see above message
      cmd.should_receive(:type).and_return(command_type).at_least.once

      assert @client.queue_thread.alive?, 'race condition encountered, please check'
      # enqueuing this will cause the command to parse nearly instantly.
      @client.command_queue.add(cmd)
      
      # join the queue thread to make sure the command gets executed.
      # since @quit is set, it should stop after processing the command, aka immediately.
      @client.queue_thread.join(0.1)

    end

    assert_false @client.queue_thread.alive?, 'check queue thread quit flag, something''s wrong'    
  end
end