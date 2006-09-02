require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'irc/client'
require 'fixtures/testing_messages'

class ClientTest < Test::Unit::TestCase
  include IRC
  include TestingMessages
  
  RETRY_WAIT = 0.5

  class DummyPlugin
    cattr_accessor :calls
    def initialize(*args)
      self.calls = nil
    end
    def teardown
      self.calls = :teardown
    end
  end
  
  def setup
    PluginManager.reset_plugins # no extra plugins hanging around!
    SocketStub.server_connected = true
    
    # create client
    @client = Client.new

    # basic configuration for easier testing
    @client.config[:nick] = 'nick'
    @client.config[:realname] = 'realname'
    @client.config[:user] = 'user'
    
  end
  
  # ----- basic callback tests -----
  
  def test_connection_callbacks
    client_connect
    assert_observing @client, @client.connection, :all
    [:data, :connected, :disconnected].each do |method|
      assert @client.respond_to?(method), "client should respond to :#{method}"
    end
  end
  
  def test_connection_notifications
    assert_callbacks @client, :connected, :disconnected do
      client_connect
      @client.quit
    end
  end
  
  def test_data_callback
    client_connect
    assert_callbacks @client, [:data, 'lol'] do
      @client.data('lol')
    end
  end
  
  def test_connection_error_callback
    err = Errno::ECONNREFUSED.new('Connection refused')
    assert_callbacks @client, [:connection_error, err] do
      @client.connection_error err
    end
  end
  
  # ----- main event callback tests -----

  def test_registered_with_server_callback
    client_connect
    assert_callback @client, :registered_with_server do
      @client.data raw_message(:welcome)
    end
  end

  def test_callbacks
    # message, [ expected callback | [expected callback, expected parameters ] ]
    nick = MessageInfo::User.new('nick', '~user@server.com')
    somenick = MessageInfo::User.new('somenick', '~someuser@server.com')
    somedude = MessageInfo::User.new('somedude', '~someuser@server.com')
    freenode = MessageInfo::User.new('user', 'n=user@foo.bar.baz.mumble.net')
    
    @client.state = {:nick => 'nick'}
    # message, expected callback or [expected callback, param1, param2...]
    [ [:nick_in_use, :nick_in_use],
      [:nick_in_use_during_registration, :nick_in_use],
      [:invalid_nick, :nick_invalid],
      [:invalid_nick_colon, :nick_invalid],
      [:nick_in_use_rfc, :nick_in_use],
      [:invalid_nick_rfc, :nick_invalid],
      [:other_nick_change, [:nick_changed, 'somenick', 'somenick2']],
      [:ping, [:server_ping, 'server.com'] ],
      [:error, :server_error],
      [:self_join, [:joined_channel, nick, '#chan'] ],
      [:other_join, [:joined_channel, somedude, '#chan'] ],
      [:self_part, [:left_channel, nick, '#chan', "reason"] ],
      [:other_part, [:left_channel, somenick, '#chan', "reason"] ],
      [:other_quit, [:quit_server, somenick, "reason"] ],
      [:freenode_quit, [:quit_server, freenode, ""] ],
      [:new_topic, [:topic_changed, '#chan', 'new topic', nil ]],
      [:topic_change, [:topic_changed, '#chan', 'new topic', somenick ]],
      [:privmsg, [:channel_message, '#chan', 'hello', somenick]],
      [:privmsg_private, [:private_message, 'nick', 'hello', somenick]],
      [:privmsg_private_mixed_case, [:private_message, 'NiCk', 'hello', somenick]],
      [:privmsg_action, [:channel_message, '#chan', "\001ACTION hello\001", somenick]],
      [:notice, [:channel_notice, '#chan', 'hello', somenick]],
      [:notice_private, [:private_notice, 'nick', 'hello', somenick]],
      [:notice_server, [:private_notice, 'nick', 'hello', 'server.com']]
    ].each do |callback|
      assert_callback( @client, callback[1] ) { @client.data raw_message(callback[0]) }
    end
  end
  
  def test_change_own_nick
    @client.state = {:nick => 'nick'}
    assert_callback( @client, [:nick_changed, 'nick', 'newnick']) do
      @client.data raw_message(:change_own_nick)
    end
    assert_equal 'newnick', @client.state[:nick], 'should change nick in state'
  end

  def test_name_list_callbacks
    client_connect
    # client should store nick lists in "scratch" space in state temporarily.    
    @client.data raw_message(:names_1) # RPL_NAMREPLY
    assert @client.state[:scratch], 'should store list of names temporarily'
    assert_equal %w{one two three}, @client.state[:scratch]['#chan'], "should strip out nick prefixes"
    @client.data raw_message(:names_2_rfc) # RPL_NAMREPLY, another one
    assert_callback @client, [:channel_name_list, '#chan', %w{one two three four five six}] do
      @client.data raw_message(:end_of_names) # RPL_ENDOFNAMES
    end
    assert_equal({}, @client.state[:scratch], "client should clean up after itself")
    # one last check
    assert_callback( @client, [:channel_name_list, '#chan', []] ){ @client.data raw_message(:end_of_names_rfc) }
  end
    
  # ----- client commands -----
  # except for start, quit, reconnect
  
  def test_send_raw
    client_connect
    2.times { gets_from_server }
    @client.send_raw('foo')
    assert_equal 'foo', gets_from_server
  end
  
  def test_change_nick
    client_connect
    2.times { gets_from_server }
    @client.change_nick('newnick')
    assert_equal 'NICK newnick', gets_from_server
    # 'nick' included because client registration includes a call to change_nick
    assert_equal ['nick', 'newnick'], @client.state[:newnick]
  end
  
  def test_join
    client_connect
    2.times { gets_from_server }
    @client.join_channel('#chan')
    assert_equal 'JOIN #chan', gets_from_server
  end
  
  def test_part
    client_connect
    2.times { gets_from_server }
    @client.leave_channel('#chan')
    assert_equal 'PART #chan', gets_from_server
    @client.leave_channel('#chan', 'reason')
    assert_equal 'PART #chan :reason', gets_from_server
  end
  
  def test_channel_message
    client_connect
    2.times { gets_from_server }
    @client.channel_message('#chan', 'hello')
    assert_equal 'PRIVMSG #chan :hello', gets_from_server
  end
  
  def test_private_message
    client_connect
    2.times { gets_from_server }
    @client.private_message('somenick', 'hello')
    assert_equal 'PRIVMSG somenick :hello', gets_from_server
  end
  
  def test_public_notice
    client_connect
    2.times { gets_from_server }
    @client.channel_notice('#chan', 'hello')
    assert_equal 'NOTICE #chan :hello', gets_from_server
  end
  
  def test_private_notice
    client_connect
    2.times { gets_from_server }
    @client.private_notice('somenick', 'hello')
    assert_equal 'NOTICE somenick :hello', gets_from_server
  end
  
  # ----- connection tests -----
  
  def test_connection
    client_connect
    assert @client.connection.socket, "client should have connected, but didn't"
    assert @client.connection.connected?, "client should be connected"
    assert @client.connected?, "client should be connected"
  end
  
  def test_connected?
    assert_false @client.connected?, 'client should be stopped'
    client_connect
    assert @client.connected?, "client should be running"
  end
  
  def test_cant_start_client_twice
    config_client
    @client.start
    assert_raise RuntimeError do
      @client.start
    end
  end
    
  def test_cant_stop_client_twice
    config_client
    @client.start
    @client.quit # first quit
    assert_raise RuntimeError do
      @client.quit # second quit
    end
  end
  
  def test_client_can_connect_twice
    client_connect
    @client.quit
    # make sure it's quit
    assert_false @client.connected?, 'client should have disconnected'
    # now make sure the client can connect a second time
    test_connection
  end
  
  def test_auto_reconnect
    client_connect
    @client.state[:nick] = 'newnick'
    @client.connection.socket.server_close # tell the stub to kill the connection
    sleep(RETRY_WAIT - 0.1)
    assert_equal [], @client.state[:newnick], 'client should have reset newnick info'
    assert_false @client.connected?, 'client should be disconnected'
    SocketStub.server_connected = true # let the client reconnect
    sleep(RETRY_WAIT + 0.1)
    assert @client.connected?, 'client should have reconnected'
    # TODO add a 'reconnecting' callback?
    assert_equal 'USER user 0 * :realname', gets_from_server
    assert_equal 'NICK newnick', gets_from_server, 'should have reregistered with former approved nick'
  end

  def test_register_on_connect
    client_connect
    assert_equal 'USER user 0 * :realname', gets_from_server
    assert_equal 'NICK nick', gets_from_server
  end

  def test_quit
    client_connect
    2.times { assert gets_from_server } # clear registration
    socket = @client.connection.socket
    @client.quit 'reason'
    assert_equal "QUIT :reason", socket.server_gets
    assert_false @client.connected?
  end
  
  def test_wait_for_quit
    client_connect
    t = Thread.new { @client.wait_for_quit }
    t.join(0) # join up real quick-like
    assert t.alive?, 'client should still be running'
    @client.quit
    t.join(0.5) # wait for it...
    assert_false t.alive?
  end
  
  # ----- configuration-related tests -----
  def test_client_loads_config_from_file
    @client = Client.new('test/fixtures/config.yaml')
    assert_equal 10000, @client.config[:port]
  end

  def test_config_required_before_start
    assert_raise Config::ConfigOptionRequired do
      @client.start
    end
  end
  
  def test_config_readonly_while_running
    assert_false @client.config.readonly?
    config_client
    @client.start
    assert @client.config.readonly?, "config should be readonly"
    @client.quit
    assert_false @client.config.readonly?, "config should be writeable"
  end
  
  def test_merge_config
    assert_equal 6667, @client.config[:port]
    @client.merge_config :port => 10000
    assert_equal 10000, @client.config[:port]
  end

  # ----- plugin tests -----
  def test_plugins_notified_of_teardown
    PluginManager.register_plugin DummyPlugin
    client_connect
    @client.quit
    assert_equal :teardown, DummyPlugin.calls
  end
  
  def test_observers_cleared
    PluginManager.register_plugin DummyPlugin # make sure there's a plugin to observe
    client_connect
    assert @client.observers[:all].size > 0, 'should be at least one plugin instance observing'
    @client.quit
    assert_equal 0, @client.observers[:all].size, 'should not be any plugins observing the client'
  end

  # ----- helpers -----
  def config_client
    @client.config[:host] = TEST_HOST
    @client.config[:port] = TEST_PORT
    @client.config[:retry_wait] = RETRY_WAIT    
    @client.config[:auto_reconnect] = true
  end
  
  def client_connect
    config_client
    @client.start
  end
  
  # def server_accept
  #   t = Thread.new { @serverclient = @server.accept } # wait for a connection
  #   yield if block_given?
  #   t.join(0.5) # with timeout in case of problems
  # end
  
  def gets_from_server
    # data = nil # scope
    # t = Thread.new { data = @serverclient.gets }
    # t.join(1) # timeout in case of problems, allows for plugin dispatch too
    data = @client.connection.socket.server_gets
    data.strip! if data
    data
  end
  
end