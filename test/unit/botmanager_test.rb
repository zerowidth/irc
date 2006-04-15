require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/botmanager'
require 'irc/client'
require 'irc/client_commands'
require 'socket' # for basic server
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
  
  def test_first_access_creates_client
    assert_equal({}, @manager.clients)
    @manager.get_events('test')
    assert @manager.clients['test']
    assert @manager.clients['test'].is_a? IRC::Client
  end
  
  def test_config_merge
    @manager.merge_config('test', {}) # init the client
    client = @manager.clients['test']
    assert_equal 10000, client.config[:port] # default (from config.yaml)
    @manager.merge_config('test', {:port=>6667} )
    assert_equal 6667, client.config[:port]
  end
  
  def test_start_client
    @manager.merge_config('test', {:host=>'localhost'} )
    assert_false @manager.clients['test'].running?
    @manager.start_client('test')
    assert @manager.clients['test'].running?
  end
  
  def test_add_and_get_events
    start_client
    client = @manager.clients['test']
    # this initialization depends on if a plugin gets loaded or not
    assert client.state[:events] == [] || client.state[:events] == nil
    assert_equal [], @manager.get_events('test')
    @manager.add_event('test', :foo)
    assert_equal [:foo], client.state[:events]
    assert_equal [:foo], @manager.get_events('test')
  end
  
  def test_add_command
    start_client
    client = @manager.clients['test']
    assert client.running?
    @manager.add_command('test', QuitCommand.new )
    Thread.new { client.wait_for_quit }.join(0.5) # wait for the quit
    assert_false client.running?
  end
  
  def test_shutdown_quits_clients
    start_client
    assert @manager.clients['test'].running?
    @manager.shutdown
    assert_false @manager.clients['test'].running?
  end
  
  def test_client_running
    assert_equal false, @manager.client_running?( 'test' )
    start_client
    assert_equal true, @manager.client_running?( 'test' )
  end
  
  def start_client
    @manager.merge_config('test', {:host=>'localhost'} )
    @manager.start_client('test')
  end

end