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
    
    def test create_with_defaults
      # only testing one default here, but if one works, the others probably do too
      conn = ConnectionPref.new_with_defaults
      assert_equal DEFAULT_NICK, conn.nick
    end
    
    def test_create_with_defaults_and_hash
      conn = ConnectionPref.new_with_defaults :nick => 'asdf'
      assert_equal DEFAULT_SERVER, conn.server
      assert_equal 'asdf', conn.nick
    end

  # channel is optional  
  #   def test_channel_validation
  #     @conn.channel = nil
  #     assert_equal(false, @conn.valid?)
  #   end

    def test_to_hash
      options = {:nick => 'n', :realname => 'r', :server => 's', :port => 1, :channel => 'c'}
      conn = ConnectionPref.new options
      api_options = {:nick => 'n', :realname => 'r', :host => 's', :port => 1, :channel => 'c'}
      assert_equal api_options, conn.to_hash
    end
end
