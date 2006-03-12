require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/message'
require 'mocks/mockclient'

include IRC
class MessageTest < Test::Unit::TestCase
  
  def setup
    @client = MockClient.new
    # for determining who "self" is
    @client.should_receive(:[]).with(:nick).and_return('rbot')
    
    @private_privmsg = ':nathan!~nathan@subdomain.domain.net PRIVMSG rbot :hello there!'
    @public_privmsg = ':nathan!~nathan@subdomain.domain.net PRIVMSG #chan :hello there!'
    @private_notice = ':nathan!~nathan@subdomain.domain.net NOTICE rbot :hello there!'
    @public_notice = ':nathan!~nathan@subdomain.domain.net NOTICE #chan :hello there!'
    @general_server_message = ':server.com 001 rbot :Welcome to the network: dude!'
    @server_ping_message = 'PING :server.com'
  end
  
  def test_parsing_from_person
    msg = Message.new(@client,@private_privmsg)
    assert_equal(@private_privmsg, msg.raw_message)
    assert_equal CMD_PRIVMSG, msg.message_type
    assert_equal ['rbot', "hello there!"], msg.params
    assert_nil msg.prefix[:server]
    assert_equal 'nathan', msg.prefix[:nick]
    assert_equal '~nathan', msg.prefix[:user]
    assert_equal 'subdomain.domain.net', msg.prefix[:host]
  end
  
  def test_parsing_from_server
    msg = Message.new(@client,@general_server_message)
    assert_equal @general_server_message, msg.raw_message
    assert_equal ['rbot', 'Welcome to the network: dude!'], msg.params 
    assert_equal 'server.com', msg.prefix[:server]
    assert_nil msg.prefix[:nick]
    assert_nil msg.prefix[:user]
    assert_nil msg.prefix[:host]
    assert_equal 'server.com', msg.sender
    assert_equal 'rbot', msg.receiver
  end
  
  # test for PING messages
  def test_parse_without_server
    msg = Message.new(@client,@server_ping_message)
    assert_nil msg.prefix[:server]
    assert_equal 'server.com', msg.params[0]
  end
  
  def test_private
    assert_private true, @private_privmsg
    assert_private true, @private_notice
    assert_private false, @public_privmsg
    assert_private false, @public_notice
    assert_private false, @general_server_message
  end
  
  def test_private_reply
    msg = Message.new(@client, @private_privmsg)
    @client.should_receive(:send_raw).with('PRIVMSG nathan :foo').once
    msg.reply('foo')
    @client.mock_verify
  end
  
  def test_public_reply
    msg = Message.new(@client, @public_privmsg)
    @client.should_receive(:send_raw).with('PRIVMSG #chan :foo bar').once
    msg.reply('foo bar')
    @client.mock_verify
  end
  
  def test_directed_reply_to_public_message
    msg = Message.new(@client, @public_privmsg)
    @client.should_receive(:send_raw).with('PRIVMSG nathan :foo bar').once
    msg.reply('foo bar',msg.sender)
    @client.mock_verify
  end
  
  def test_reply_with_command
    msg = Message.new(@client, @general_server_message)
    @client.should_receive(:send_raw).with('PONG 12345').once
    msg.reply_command(CMD_PONG, '12345')
    @client.mock_verify
  end
  
  private # --------------------------------------------
  
  def assert_private(should_be_private, str)
    msg = Message.new(@client,str)
    assert_equal should_be_private, msg.private?
  end
  
end
