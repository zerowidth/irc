require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/plugin'
require 'stubs/command_queue_stub'

class PluginTest < Test::Unit::TestCase
  include IRC
  
  # there's not much to test here, except for helper methods... make 'em public!
  class TestPlugin < IRC::Plugin
    public :reply, :reply_command, :private_message?
  end
  
  def setup 
    @cq = CommandQueueStub.new
    @config = {}
    @state = {:nick=>'rbot'}
    @plugin = TestPlugin.new(@cq, @config, @state)
    
    # test messages:
    @private_privmsg = Message.new ':nathan!~nathan@subdomain.domain.net PRIVMSG rbot :hello there!'
    @public_privmsg = Message.new ':nathan!~nathan@subdomain.domain.net PRIVMSG #chan :hello there!'
    @private_notice = Message.new ':nathan!~nathan@subdomain.domain.net NOTICE rbot :hello there!'
    @public_notice = Message.new ':nathan!~nathan@subdomain.domain.net NOTICE #chan :hello there!'
    @general_server_message = Message.new ':server.com 001 rbot :Welcome to the network: dude!'
    @ping_message = Message.new 'PING :server.com'
  end
  
  def test_private_message
    # test with normal :nick set
    assert_equal true, @plugin.private_message?(@private_privmsg)
    assert_equal false, @plugin.private_message?(@public_privmsg)
    assert_equal true, @plugin.private_message?(@private_notice)
    assert_equal false, @plugin.private_message?(@public_notice)
    assert_equal false, @plugin.private_message?(@general_server_message)
    assert_equal false, @plugin.private_message?(@ping_message)
  end
  
  def test_private_reply
    @plugin.reply(@private_privmsg, 'hello')
    assert_replied_with('PRIVMSG nathan :hello')
  end
  
  def test_public_reply
    @plugin.reply(@public_privmsg, 'hello')
    assert_replied_with('PRIVMSG #chan :hello')
  end
  
  def test_reply_command
    @plugin.reply_command(@ping_message, CMD_PONG, 'server.com stuff')
    assert_replied_with('PONG server.com stuff')
  end
  
  def test_reply_command_to_general_message
    @plugin.reply_command(@general_server_message, CMD_PONG, 'test')
    assert_replied_with('PONG test')
  end

  # test helper
  def assert_replied_with(str)
    assert_equal 1, @cq.queue.size
    assert_equal SendCommand, @cq.queue[0].class
    assert_equal str, @cq.queue[0].data
  end

end