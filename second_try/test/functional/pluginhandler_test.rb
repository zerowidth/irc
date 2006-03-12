require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
#require 'irc/config'
require 'rubygems'
require 'flexmock'
require 'mocks/mockmessage'
require 'mocks/mockplugin'

include IRC
class PluginHandlerTest < Test::Unit::TestCase
  
  # buggy plugin!
  class BrokenPlugin < Plugin
    def privmsg(msg)
      raise 'kaboom!'
    end
  end
    
  def setup
    PluginHandler.destroy_instance # fresh new instance every time!
    @plugins = PluginHandler.instance
    @testmessage = MockMessage.new 
    @testplugin = MockPlugin.new
  end
  
  def teardown
    @plugins.shutdown
  end
  
  # sadly, it's not practical to test each component alone...
  def test_basic_registration_and_dispatch    

    @testplugin.add_method(:privmsg)
    @testplugin.should_receive(:method_called).with(:privmsg).once
    @testplugin.add_method(:m001)
    @testplugin.should_receive(:method_called).with(:m001).once

    # test a command, and then a numeric reply
    retval = [CMD_PRIVMSG,RPL_WELCOME]
    @testmessage.should_receive(:message_type).twice.and_return {retval.shift}
    
    # register the plugin
    PluginHandler.register_plugin(@testplugin, CMD_PRIVMSG, RPL_WELCOME)

    # this should call message.message_type
    # and then call plugin.privmsg
    @plugins.dispatch_message(@testmessage) # CMD_PRIVMSG
    @plugins.dispatch_message(@testmessage) # RPL_WELCOME

    # check that it happened
    @testmessage.mock_verify
    @testplugin.mock_verify

  end
  
  def test_dispatch_to_all
    
    @testplugin.add_method(:message) # generic message handler (for :all)
    @testplugin.should_receive(:method_called).with(:message).twice
    
    retval = [CMD_PRIVMSG,RPL_WELCOME]
    @testmessage.should_receive(:message_type).twice.and_return {retval.shift}
    
    # register for all
    PluginHandler.register_plugin(@testplugin, :all)
    
    @plugins.dispatch_message(@testmessage) # CMD_PRIVMSG
    @plugins.dispatch_message(@testmessage) # RPL_WELCOME
    
    @testmessage.mock_verify
    @testplugin.mock_verify
    
  end
  
  # make sure that when dispatching something to a plugin that's buggy, it doesn't
  # cause the rest of the program to explode all over the place
  def test_plugin_exceptions_are_caught
    PluginHandler.register_plugin(BrokenPlugin, CMD_PRIVMSG)
    
    @testmessage.should_receive(:message_type).once.and_return(CMD_PRIVMSG)

    # if this raises an exception, the test will fail.
    @plugins.dispatch_message(@testmessage)
  end
  
end
