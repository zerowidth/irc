require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/plugin'
require 'stubs/command_queue_stub'

class PluginTest < Test::Unit::TestCase
  include IRC
  
  # there's not much to test here, except for helper methods... make 'em public!
  class IRC::Plugin
    public :reply, :send_command, :reply_action
    public :directed_message?, :private_message?, :who_sent?, :where_sent?
  end
  # test plugin, does nothing (on purpose)
  class TestPlugin < IRC::Plugin
  end
  class IRC::SendCommand
    attr_reader :data
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
  
  # test the message query helpers
  
  def test_directed_message
    { @private_privmsg => true, 
      @public_notice => true, 
      @general_server_message => false }.each do |msg, directed|
      assert_equal directed, @plugin.directed_message?(msg)
    end
  end

  def test_private_message
    # test with normal :nick set
    assert_equal true, @plugin.private_message?(@private_privmsg)
    assert_false @plugin.private_message?(@public_privmsg)
    assert_equal true, @plugin.private_message?(@private_notice)
    assert_false @plugin.private_message?(@public_notice)
    assert_false @plugin.private_message?(@general_server_message)
    assert_false @plugin.private_message?(@ping_message)
  end
  
  def test_who_sent
    # privmsg and notices are the easy case
    [@private_privmsg, @public_privmsg, @private_notice, @public_notice].each do |msg|
      assert_equal( 'nathan', @plugin.who_sent?( msg ) )
    end
    # general messages
    assert_equal( 'server.com', @plugin.who_sent?( @general_server_message ) )
    assert_equal( 'server.com', @plugin.who_sent?( @ping_message ) )
  end
  
  def test_where_sent
    assert_equal 'rbot', @plugin.where_sent?(@private_privmsg)
    assert_equal '#chan', @plugin.where_sent?(@public_privmsg)
    assert_equal 'rbot', @plugin.where_sent?(@general_server_message)
  end
  
  # test the reply/send helpers
  
  def test_private_reply
    @plugin.reply(@plugin.who_sent?( @private_privmsg ), 'hello')
    assert_replied_with('PRIVMSG nathan :hello')
  end
  
  def test_public_reply
    @plugin.reply(@plugin.where_sent?(@public_privmsg), 'hello')
    assert_replied_with('PRIVMSG #chan :hello')
  end
  
  # this is interesting: sometimes irc clients or the server don't match case for nicknames.
  # make sure the reply code works with the nick being differently-cased from the actual nick.
  def test_private_reply_case_insensitive
    @state[:nick] = 'rBoT'
    @plugin.reply(@plugin.who_sent?(@private_privmsg),'hello')
    assert_replied_with('PRIVMSG nathan :hello')
  end
  
  def test_send_command
    @plugin.send_command(CMD_PONG, 'server.com stuff')
    assert_replied_with('PONG server.com stuff')
  end
  
  def test_action_command
    @plugin.reply_action(@plugin.who_sent?(@private_privmsg),'action!')
    assert_replied_with("PRIVMSG nathan :\001action!\001")
  end
  
  def test_action_command_to_chan
    
  end

  # test helper
  def assert_replied_with(str)
    assert_equal 1, @cq.queue.size
    assert_equal SendCommand, @cq.queue[0].class
    assert_equal str, @cq.queue[0].data
  end

end