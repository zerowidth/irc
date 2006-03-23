require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/core_plugin'
require 'stubs/command_queue_stub'

# reveal internals for easy testing
class IRC::NickCommand
  attr_reader :nick
end
# same for PluginManager, for testing registration of the core plugin
class IRC::PluginManager
  attr_reader :plugins, :handlers
end

class CorePluginTest < Test::Unit::TestCase
  include IRC
  
  def setup
    @cq = CommandQueueStub.new
    @config = {
      :nick => 'nick'
    }
    @state = {}
    
    @plugin = CorePlugin.new(@cq,@config,@state)
    
    @msg_welcome = Message.new('001 :Welcome to the network')
    @msg_change_own_nick = Message.new(':nick!~user@server.com NICK :newnick')
    @msg_other_nick_change = Message.new(':somenick!~someuser@server.com NICK :somenick2')
    @msg_nick_in_use = Message.new(':server.com 433 nick newnick :Nickname already in use')
    @msg_nick_in_use_during_registration = Message.new(':server.com 433 * nick :Nickname already in use')
    @msg_invalid_nick = Message.new(':server.com 432 nick / :Erroneous Nickname')
    # colon gets parsed out by server (depends on ircd?), so the message is weird
    @msg_invalid_nick_colon = Message.new(':server.come 432 nick  :Erroneous Nickname')
    # these two errors comply with RFC, unlike the ircd i tested this with
    @msg_nick_in_use_rfc = Message.new(':server.com 433 newnick :Nickname already in use')
    @msg_invalid_nick_rfc = Message.new(':server.com 432 / :Erroneus Nickname')
    
  end
  
  def teardown
    
  end
  
  def test_core_plugin_registration
    pm = PluginManager.new(@cq, @config, @state)
    assert_equal CorePlugin, pm.plugins.first.class
    # check that core plugin got registered for the right things
    [RPL_WELCOME, CMD_NICK, ERR_NICKNAMEINUSE, ERR_ERRONEUSNICKNAME].each do |command|
      assert pm.handlers[command]
    end
  end
  
  def test_welcome_message_sets_nick
    # welcome, RPL_WELCOME, is a response to a successful registration
    # with a server. 
    # the current nickname in the state should be set when this happens.
    assert_equal nil, @state[:nick]
    @state[:newnick] = ['nick']
    @plugin.m001(@welcome)
    assert_equal 'nick', @state[:nick]
    assert_equal [], @state[:newnick]
  end
  
  def test_nick_message_sets_nick
    # NICK message, at least when it's involving one's own nick, should be in
    # response to a NICK command. NICK command will have set :newnick in the state.
    @state[:nick] = 'nick'
    @state[:newnick] = ['newnick']
    @plugin.nick(@msg_change_own_nick)
    assert_equal 'newnick', @state[:nick]
    # newnick should be cleared, since it doesn't apply anymore
    assert_equal [], @state[:newnick]
  end
  
  def test_nick_message_with_multiple_changes
    assert @state.empty?
    @state[:nick] = 'nick'
    # pretend nick got changed twice in a row, but this is the response to the first try.
    @state[:newnick] = ['newnick','newnick2']
    @plugin.nick(@msg_change_own_nick)
    assert_equal 'newnick', @state[:nick]
    assert_equal ['newnick2'], @state[:newnick]
  end
  
  def test_other_nick_change_ignored
    @state[:nick] = 'nick'
    @plugin.nick(@msg_other_nick_change)
    assert_equal 'nick', @state[:nick]
  end
  
  def test_nickname_in_use
    @state[:nick] = 'nick'
    @state[:newnick] = ['newnick']
    @plugin.m433(@msg_nick_in_use)
    assert_equal 'nick', @state[:nick]
    assert_equal [], @state[:newnick]
  end
  
  def test_nickname_in_use_pre_registration
    # nick not set in state yet, since registration hasn't happened
    @state[:newnick] = ['nick']
    @plugin.m433(@msg_nick_in_use_during_registration)
    # check that a new nick command was pushed:
    assert_equal NickCommand, @cq.queue.first.class
    assert_equal 'nick_', @cq.queue.first.nick
  end
  
  def test_invalid_nick
    @state[:nick] = 'nick'
    @state[:newnick] = ['/']
    @plugin.m432(@msg_invalid_nick)
    assert_equal [], @state[:newnick]
  end
  
  def test_invalid_nick_before_registration
    @state[:newnick] = ['/']
    assert_raises(RuntimeError) { @plugin.m432(@msg_invalid_nick) }
    assert_equal [], @state[:newnick] 
  end
  
  # edge case, but this could break things.. so test it anyway
  def test_invalid_nick_just_colon
    @state[:nick] = 'nick'
    @state[:newnick] = [':']
    @plugin.m432(@msg_invalid_nick_colon)
    assert_equal [], @state[:newnick]
  end
  
  # RFC-compliant nickname in use and invalid nick messages
  # dunno why it's different, but the irc server i tested against returned
  # things differently than the RFC specifies.

  def test_rfc_compliant_errors
    @state[:nick] = 'nick'
    @state[:newnick] = %w{newnick, newnick2}
    @plugin.m433(@msg_nick_in_use_rfc)
    assert_equal ['newnick2'], @state[:newnick]
    @plugin.m432(@msg_invalid_nick_rfc)    
    assert_equal [], @state[:newnick]
  end

end