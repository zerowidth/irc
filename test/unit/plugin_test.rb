require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'irc/plugin'

class PluginTest < Test::Unit::TestCase
  include IRC
  
  class TestPlugin < IRC::Plugin
    attr_reader :client
  end
    
  def test_registration_on_include
    # there may be other plugins registered (core plugin)
    # or all formerly-registered plugins may have been reset during testing
    # so do some trickery here to work around that
    Plugin.send :inherited, TestPlugin # invoke a private method, whee!
    plugins = PluginManager.instantiate_plugins(:client)
    assert_false plugins.empty?
    tp = plugins.detect {|p| p.is_a?(TestPlugin) }
    assert tp
    assert_equal :client, tp.client
  end
  
end