require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/client'
require 'irc/client_proxy'

class ClientProxyTest < Test::Unit::TestCase
  include IRC
  def setup
    @server = TCPServer.new('localhost', 10000) # so client starts don't fail
    @client = Client.new(File.expand_path(File.dirname(__FILE__)+'/../fixtures/config.yaml'))
    @client.config[:host] = 'localhost'
    @proxy = ClientProxy.new(@client)
  end
  
  def teardown
    @server.close
  end
  
  def test_config
    assert_equal 10000, @proxy.config(:port) # default
  end
  
  def test_merge_config
    assert_equal 10000, @proxy.config(:port)
    @proxy.merge_config :port => 12345
    assert_equal 12345, @proxy.config(:port)
  end
  
  def test_proxy_start
    assert_false @client.running?, 'client should be stopped'
    @proxy.start
    assert @client.running?, 'client should be running'
  end
  
  def test_proxy_start_running_quit
    assert_false @proxy.running?, 'proxy should not be running'
    @proxy.start
    assert @proxy.running?, 'proxy should be running'
    @proxy.quit 'reason'
    assert_false @proxy.running?
  end
  
  def test_state
    assert_nil @proxy.state(:foo) # just make sure it doesn't throw any exceptions
  end
  
  def test_add_and_get_events
    @proxy.start
    # this initialization depends on if a plugin gets loaded or not
    assert @client.state[:events] == [] || @client.state[:events] == nil
    assert_equal [], @proxy.events
    @proxy.add_event(:foo) # doesn't matter that this isn't an actual Event
    assert_equal [:foo], @client.state[:events]
    assert_equal [:foo], @proxy.events
  end
  
  def test_add_command
    @proxy.start
    @proxy.add_command QuitCommand.new
    Thread.new { @client.wait_for_quit }.join(0.5) # wait for the quit
    assert_false @client.running?, 'client should have quit'
  end
  
end