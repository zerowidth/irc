require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/botmanager'
require 'irc/client'
require 'socket' # for basic server
#require 'mocks/command_mock' # mock command for command execution testing

class BotManagerTest < Test::Unit::TestCase
  include IRC
  
  def setup
    @manager = BotManager.new(File.expand_path(File.dirname(__FILE__)+'/../fixtures/config.yaml'))
    @server = TCPServer.new('localhost', 10000) # so client starts don't fail
  end
  def teardown
    @manager.shutdown # not really necessary, but whatev
    @server.close
  end
  
  def test_get_new_clients
    # these .client calls should return new, different clients
    one = @manager.client(:one) # use a symbol...
    two = @manager.client('two') # or a string ... or whatever! it's a hash!
    assert_false one == two # make sure they're not the same thing
  end
  
  def test_get_same_client
    c = @manager.client('client')
    assert_equal c, @manager.client('client')
    c.start
    assert_equal true, c.running?
    assert_equal true, @manager.client('client').running?
  end
  
  def test_clients_use_config_file
    c = @manager.client(:c)
    assert_equal 10000, c.config[:port] # not default, set in config file above
  end
  
  def test_quit_quits_clients
    c = @manager.client(:c)
    assert_equal false, c.running?
    c.start
    assert_equal true, c.running?
    @manager.shutdown
    assert_equal false, c.running?
  end
  
end