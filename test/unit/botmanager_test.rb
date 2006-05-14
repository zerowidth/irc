require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/botmanager'
require 'irc/client'
require 'irc/client_commands'
require 'socket' # for basic server
require 'irc/client_proxy'
#require 'mocks/command_mock' # mock command for command execution testing

class BotManagerTest < Test::Unit::TestCase
  include IRC
  
  class IRC::BotManager
    attr_reader :clients
  end
  
  def setup
    @manager = BotManager.new(File.expand_path(File.dirname(__FILE__)+'/../fixtures/config.yaml'))
    @server = TCPServer.new('localhost', 10000) # so client starts don't fail
  end
  
  def teardown
    @manager.shutdown # not really necessary, but whatev
    @server.close
  end
  
  def test_client_creates_client_object
    assert_equal( {}, @manager.clients)
    client = @manager.client(:client_name)
    assert_equal ClientProxy, client.class
    assert @manager.clients[:client_name]
  end
  
  def test_remove_client
    client = @manager.client(:client_name)
    assert_equal ClientProxy, client.class
    @manager.remove_client :client_name
    assert_equal({}, @manager.clients)
  end

  def test_shutdown_quits_and_deletes_clients
    start_client :one
    start_client :two
    one = @manager.client(:one)
    two = @manager.client(:two)
    assert one.running?
    assert two.running?
    @manager.shutdown
    assert_false one.running?
    assert_false two.running?
    assert @manager.clients.empty?
  end

  def start_client(client_name)
    client = @manager.client(client_name)
    client.merge_config :host=>'localhost'
    client.start
  end

end