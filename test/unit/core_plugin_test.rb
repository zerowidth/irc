require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'irc/plugins/core_plugin'
require 'stubs/client_stub'
require 'fixtures/testing_messages.rb'

# reveal internals for easy testing
class IRC::NickCommand
  attr_reader :nick
end
class IRC::SendCommand
  attr_reader :data
end
# same for PluginManager, for testing registration of the core plugin
class IRC::PluginManager
  attr_reader :plugins
end

class CorePluginTest < Test::Unit::TestCase
  include IRC
  include TestingMessages
  
  def setup
    @client = ClientStub.new
    @client.config = {
      :nick => 'nick',
      :newnick => []
    }
    @plugin = CorePlugin.new(@client)
  end
  
  def test_core_plugin_callbacks_match_client
    [:registered_with_server, :nick_change, :nick_in_use, :nick_invalid, 
     :server_ping].each do |callback|
      assert @plugin.respond_to?(callback), "plugin doesn't respond to :#{callback}"
    end
  end

  def test_registration_sets_nick
    # welcome, RPL_WELCOME, is a response to a successful registration
    # with a server. 
    # the current nickname in the state should be set when this happens.
    assert_equal nil, @client.state[:nick]
    @client.state[:newnick] = ['nick']
    @plugin.registered_with_server
    assert_equal 'nick', @client.state[:nick]
    assert_equal [], @client.state[:newnick]
  end
    
  def test_nick_change_sets_nick
    # NICK message, at least when it's involving one's own nick, should be in
    # response to a NICK command. NICK command will have set :newnick in the state.
    @client.state[:nick] = 'nick'
    @client.state[:newnick] = ['newnick']
    @plugin.nick_change 'nick', 'newnick' # callback
    assert_equal 'newnick', @client.state[:nick]
    # newnick should be cleared, since it doesn't apply anymore
    assert_equal [], @client.state[:newnick]
  end  
  
  def test_nick_message_with_multiple_changes
    assert @client.state.empty?
    @client.state[:nick] = 'nick'
    # pretend nick got changed twice in a row, but this is the response to the first try.
    @client.state[:newnick] = ['newnick','newnick2']
    @plugin.nick_change 'nick', 'newnick'
    assert_equal 'newnick', @client.state[:nick]
    assert_equal ['newnick2'], @client.state[:newnick]
  end
  
  def test_other_nick_change_ignored
    @client.state[:nick] = 'nick'
    @plugin.nick_change 'somenick', 'somenick2' # callback
    assert_equal 'nick', @client.state[:nick]
  end

  def test_nickname_in_use
    @client.state[:nick] = 'nick'
    @client.state[:newnick] = ['newnick']
    @plugin.nick_in_use# message(:nick_in_use)
    assert_equal 'nick', @client.state[:nick]
    assert_equal [], @client.state[:newnick]
  end

  def test_nickname_in_use_pre_registration
    # nick not set in state yet, since registration hasn't happened
    @client.state[:nick] = nil
    @client.state[:newnick] = ['nick']
    @plugin.nick_in_use# message(:nick_in_use_during_registration)
    assert @client.calls[:change_nick]
    assert_equal 'nick_', @client.calls[:change_nick].first[0] # first arg of first call
  end
  
  def test_invalid_nick
    @client.state[:nick] = 'nick'
    @client.state[:newnick] = ['/']
    @plugin.nick_invalid# message(:invalid_nick)
    assert_equal [], @client.state[:newnick]
  end
    
  def test_invalid_nick_before_registration
    @client.state[:newnick] = ['/']
    assert_raises(RuntimeError) { @plugin.nick_invalid } # message(:msg_invalid_nick)
    assert_equal [], @client.state[:newnick]
  end
    
  # edge case, but this could break things.. so test it anyway
  # (could be a problem with message parsing, or message params)
  def test_invalid_nick_just_colon
    @client.state[:nick] = 'nick'
    @client.state[:newnick] = [':']
    @plugin.nick_invalid# message(:invalid_nick_colon)
    assert_equal [], @client.state[:newnick]
  end
    
  # RFC-compliant nickname in use and invalid nick messages
  # dunno why it's different, but the irc server i tested against returned
  # things differently than the RFC specifies.
  
  def test_rfc_compliant_errors
    @client.state[:nick] = 'nick'
    @client.state[:newnick] = %w{newnick, newnick2}
    @plugin.nick_in_use# message(:nick_in_use_rfc)
    assert_equal ['newnick2'], @client.state[:newnick]
    @plugin.nick_invalid# message(:invalid_nick_rfc)    
    assert_equal [], @client.state[:newnick]
  end

  # make absolutely sure the :newnick state is maintained!
  def test_newnick_state_maintenance
    @client.state[:nick] = 'nick'
    @client.state[:newnick] = ['foo', 'gnar'] # start with a couple nicks pushed on the stack
    @plugin.nick_invalid
    assert_equal ['gnar'], @client.state[:newnick], 'should have popped foo, not gnar'
    @client.state[:newnick] = ['foo', 'gnar']
    @plugin.nick_in_use
    assert_equal ['gnar'], @client.state[:newnick], 'should have popped foo, not gnar'
  end

  # server keepalive
  def test_ping_pong
    @plugin.server_ping message(:ping).params[0]
    # check that a pong command was returned
    assert @client.calls[:send_raw], 'should have sent...'
    assert_equal 'PONG server.com', @client.calls[:send_raw].first[0]
  end
  
end