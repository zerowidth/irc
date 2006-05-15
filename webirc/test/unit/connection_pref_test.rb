require File.dirname(__FILE__) + '/../test_helper'

class ConnectionPrefTest < Test::Unit::TestCase
  fixtures :connection_prefs, :users

    def setup
     @conn = connection_prefs(:quentin)
    end

    def test_basic
      assert(@conn.valid?, "connection should be valid!")
    end

    def test_nick_validation
      @conn.nick = nil
      assert_equal(false, @conn.valid?)
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

    def test_user_relationship
      assert_equal users(:quentin), connection_prefs(:quentin).user
    end

  # channel is optional  
  #   def test_channel_validation
  #     @conn.channel = nil
  #     assert_equal(false, @conn.valid?)
  #   end

    def test_to_hash
      options = {:nick => 'n', :realname => 'r', :server => 's', :port => 1, :channel => 'c'}
      conn = ConnectionPref.new options
      assert_equal options, conn.to_hash
    end
end
