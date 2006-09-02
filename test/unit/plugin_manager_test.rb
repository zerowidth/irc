require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'irc/plugin_manager'

class PluginManagerTest < Test::Unit::TestCase
  include IRC
  
  class TestPlugin
    attr_reader :client
    def initialize(client)
      @client = client
    end
  end

  def setup
    
    PluginManager.reset_plugins
    
    # @private_privmsg = Message.parse ':nathan!~nathan@subdomain.domain.net PRIVMSG rbot :hello there!'
    # @general_server_message = Message.parse ':server.com 001 rbot :Welcome to the network: dude!'
    # @unknown_message = Message.parse ':server.com 123 rbot :who knows what this is'
    # @unknown_message_two = Message.parse ':server.com 124 rbot :who knows what this is'

  end
  
  def test_registration
    # test that plugin registrations get stored in the class singleton
    assert_equal 0, PluginManager.plugins.size
    PluginManager.register_plugin TestPlugin
    assert_equal 1, PluginManager.plugins.size
  end
  
  def test_instantiation
    # instantiation of the plugin manager class should "freeze" the plugin list
    # by instantiating everything
    PluginManager.register_plugin TestPlugin
    assert_equal 1, PluginManager.plugins.size
    # instantiate it
    plugins = PluginManager.instantiate_plugins(:client)
    assert_equal 1, plugins.size
    assert_equal :client, plugins.first.client
  end
  
  def test_instantiation_with_no_plugins
    p = PluginManager.instantiate_plugins(:client)
    assert_equal 0, p.size
  end
  
  def test_duplicate_registrations_instantiated_once
    # register it twice
    PluginManager.register_plugin TestPlugin
    PluginManager.register_plugin TestPlugin
    plugins = PluginManager.instantiate_plugins(:client)
    assert_equal 1, plugins.size
  end
  
  def test_load_plugins_from_dir
    PluginManager.load_plugins_from_dir 'plugin_test'
    assert_equal 1, PluginManager.plugins.size, 'ExamplePlugin should have been registered'
    assert_equal ExamplePlugin, PluginManager.plugins.first, 'should be an example plugin'
  end
  
  def test_load_plugins_from_invalid_dir
    assert_raise(Errno::ENOENT) do
      pm = PluginManager.load_plugins_from_dir 'invalid_directory'
    end
  end
  
end