require File.dirname(__FILE__) + '/../test_helper'

class ConnectionTest < Test::Unit::TestCase

  def setup
    @conn = Connection.new
    @conn.nick = 'nick'
    @conn.realname = 'realname'
    @conn.server = 'server.com'
    @conn.port = 6667
    @conn.channel = '#chan'
  end
  
  def test_basic
    assert(@conn.valid?, "connection should be valid!")
  end
  
  def test_creation_with_options
    conn = Connection.new :nick => 'n', :realname => 'r', :server => 's', :port => 1, :channel => 'c'
    assert_equal 'n', conn.nick
    assert_equal 'r', conn.realname
    assert_equal 's', conn.server
    assert_equal 1, conn.port
    assert_equal 'c', conn.channel
  end

  def test_nick_validation
    @conn.nick = nil
    assert_equal(false, @conn.valid?)
    # nick must only be: 
    @conn.nick = ''
  end
  
  def test_realname_validation
    @conn.realname = nil
    assert_equal(false, @conn.valid?)
  end
  
  def test_server_validation
    @conn.server = nil
    assert_equal(false, @conn.valid?)
  end
  
  def test_port_validation
    @conn.port = nil
    assert_equal(false, @conn.valid?)
  end
  
  def test_channel_validation
    @conn.channel = '#foo'
    assert(@conn.valid?, "channel should be valid!")
  end
end
