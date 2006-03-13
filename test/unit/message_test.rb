require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/message'

include IRC
class MessageTest < Test::Unit::TestCase
  
  def setup
    @private_privmsg = ':nathan!~nathan@subdomain.domain.net PRIVMSG rbot :hello there!'
    @general_server_message = ':server.com 001 rbot :Welcome to the network: dude!'
    @server_ping_message = 'PING :server.com'
  end
  
  def test_parsing_from_person
    msg = Message.new(@private_privmsg)
    assert_equal(@private_privmsg, msg.raw_message)
    assert_equal CMD_PRIVMSG, msg.message_type
    assert_equal ['rbot', "hello there!"], msg.params
    assert_nil msg.prefix[:server]
    assert_equal 'nathan', msg.prefix[:nick]
    assert_equal '~nathan', msg.prefix[:user]
    assert_equal 'subdomain.domain.net', msg.prefix[:host]
  end
  
  def test_parsing_from_server
    msg = Message.new(@general_server_message)
    assert_equal @general_server_message, msg.raw_message
    assert_equal ['rbot', 'Welcome to the network: dude!'], msg.params 
    assert_equal 'server.com', msg.prefix[:server]
    assert_nil msg.prefix[:nick]
    assert_nil msg.prefix[:user]
    assert_nil msg.prefix[:host]
    assert_equal 'server.com', msg.sender
    #assert_equal 'rbot', msg.receiver
  end
  
  # test parsing for weird PING messages
  def test_parse_without_server
    msg = Message.new(@server_ping_message)
    assert_nil msg.prefix[:server]
    assert_equal 'server.com', msg.params[0]
    assert_equal 'server.com', msg.sender
  end
  
end
