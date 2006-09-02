require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require "irc/plugins/state_manager"
require 'stubs/client_stub'

class StateManagerPluginTests < Test::Unit::TestCase
  
  include IRC
  
  def setup
    @client = ClientStub.new
    @client.state = {
      :nick => 'nick',
      :topics => {
        '#chan' => 'chan topic',
        '#chan2' => 'chan2 topic',
#        'somenick' => '' # TODO change this to 'private conversation with ..., and handle'
      },
      :names => {
        '#chan'=>['somenick', 'nick', 'user'], # has own nick (nick)
        '#chan2' => ['nick', 'name2', 'somenick'], 
#        'somenick' => ['somenick'] # private message
      },
      :events => []
    }
    
    @plugin = StateManagerPlugin.new(@client)
    
    @nick = MessageInfo::User.new('nick', '~user@server.com')
    @somenick = MessageInfo::User.new('somenick', '~someuser@server.com')
    @somedude = MessageInfo::User.new('somedude', '~someuser@server.com')
    @freenode = MessageInfo::User.new('user', 'n=user@foo.bar.baz.mumble.net')
  end
  
  # ----- connection and general -----
  # make sure an event queue doesn't get any larger than it's supposed to
  def test_max_queue_size
    # make sure the max size got set first (should be a default in the plugin!)
    assert @client.config[:max_event_queue_size]
    (@client.config[:max_event_queue_size]+100).times do 
      @plugin.channel_message '#chan', 'hello', @somenick
    end    
    assert_equal @client.config[:max_event_queue_size], @client.state[:events].size
  end

  # plugin should autorejoin any channels it was in if it reconnects
  def test_autorejoin
    # test without any channels first
    topics, @client.state[:topics] = @client.state[:topics], [] # save 'em for a minute
    @plugin.registered_with_server
    assert !@client.calls, 'no calls should have been made to client yet'
    
    # now with two channels
    @client.state[:topics] = topics
    @plugin.registered_with_server
    
    assert_equal [ *(topics.map {|t| [t[0]]}) ], @client.calls[:join_channel], 'should have autorejoined!'
  end
  
  def test_disconnected
    @plugin.disconnected
    assert_first_event DisconnectedEvent, :who => nil, :where => nil, :what => nil, :context => :server
  end
  
  def test_connection_error
    err = Errno::ECONNREFUSED.new('Connection refused')
    @plugin.connection_error err
    assert_first_event ConnectionErrorEvent, :what => err, :context => :server
  end
  
  # ----- nick state maintenance -----
  
  # should change own nick in nick lists and add event
  def test_nick_when_self
    @plugin.nick_changed 'nick', 'newnick'
    assert_equal 'newnick', @client.state[:names]['#chan'][1]
    # should be an event listed in every channel
    assert_event @client.state[:events].last, NickChangedEvent,
      :who => 'nick', :where => '#chan', :what => 'newnick', :context => :self
    assert_event @client.state[:events].first, NickChangedEvent,
      :who => 'nick', :where => '#chan2', :what => 'newnick', :context => :self
  end
    
  # should update all instances of somenick with somenick2 and add event (one per chan)
  def test_nick_when_other
    @plugin.nick_changed 'somenick', 'somenick2'
    assert_equal 'somenick2', @client.state[:names]['#chan'][0]
    assert_equal 'somenick2', @client.state[:names]['#chan2'][2]
    # event should exist for all current channels
    assert_event @client.state[:events][1], NickChangedEvent, 
      :who => 'somenick', :where => '#chan', :what => 'somenick2', :context => nil
    assert_event @client.state[:events][0], NickChangedEvent, 
      :who => 'somenick', :where => '#chan2', :what => 'somenick2', :context => nil
  
    # TODO: private message gets updated with new name? probably.
    # TODO: is this a good idea? might b0rk the front-end app, by changing tab title?
  end

  # ----- channel maintenance -----

  def test_self_join
    @client.state[:names]['#chan'] = nil
    @client.state[:topics]['#chan'] = nil
    @client.state[:events] = []
    @plugin.joined_channel @nick, '#chan'
    assert_equal [], @client.state[:names]['#chan'], 'should have registered as joining in :names'
    assert_equal '', @client.state[:topics]['#chan'], 'should have set a blank topic for #chan'
    assert_first_event JoinEvent,
      :who => 'nick', :where => '#chan', :what => '~user@server.com', :context => :self
  end

  def test_other_join
    @plugin.joined_channel @somedude, '#chan'
    assert_equal 4, @client.state[:names]['#chan'].size, 'should be 4 names in #chan'
    assert_first_event JoinEvent,
      :who => 'somedude', :where => '#chan', :what => '~someuser@server.com', :context => nil
  end
    
  def test_self_part
    @plugin.left_channel @nick, '#chan', "reason"
    assert_equal nil, @client.state[:names]['#chan'], "didn't unset names for channel"
    assert_equal nil, @client.state[:topics]['#chan'], "didn't unset topic for channel"
    assert_first_event PartEvent, 
      :who => 'nick', :where => '#chan', :what => "reason", :context => :self
  end
    
  def test_other_part
    @plugin.left_channel @somenick, '#chan', 'reason'
    assert_false @client.state[:names]['#chan'].include?('somenick'), 'somenick is still in the names list'
    # make sure he didn't leave the other channel!
    assert_equal ['nick', 'name2', 'somenick'], @client.state[:names]['#chan2'], 'did he leave?'
    assert_first_event PartEvent, 
      :who => 'somenick', :where => '#chan', :what => 'reason' # extra info
  end
    
  def test_other_quit
    @plugin.quit_server @somenick, 'reason'
    assert_false @client.state[:names]['#chan'].include?('somenick'), 'somenick is still in the names list'
    assert_equal ['nick', 'name2'], @client.state[:names]['#chan2']
    assert_event @client.state[:events].last, QuitEvent, 
      :who => 'somenick', :where => '#chan', :what => 'reason' # extra info
    assert_event @client.state[:events].first, QuitEvent, 
      :who => 'somenick', :where => '#chan2', :what => 'reason'
  end
  
  # trying to track down a bug, this wasn't it. oh well, leave it here.
  def test_freenode_quit
    @plugin.quit_server @freenode, ''
    assert_event @client.state[:events].last, QuitEvent, 
      :who => 'user', :where => '#chan', :what => ''
  end
  
  def test_topic
    @plugin.topic_changed '#chan', 'new topic', nil
    assert_equal 'new topic', @client.state[:topics]['#chan']
    assert_first_event TopicChangedEvent, :who => nil, :where => '#chan', :what => 'new topic'
  end
    
  def test_topic_change
    @plugin.topic_changed '#chan', 'new topic', 'somenick'
    assert_equal 'new topic', @client.state[:topics]['#chan']
    assert_first_event TopicChangedEvent, :who => 'somenick', :where => '#chan', :what => 'new topic'
  end

  def test_channel_name_list
    newnames = %w{one @two three}
    @plugin.channel_name_list '#chan', newnames
    assert_equal newnames, @client.state[:names]['#chan']
    assert_event @client.state[:events].last, NameListEvent, 
      :who => nil, :where => '#chan', :what => newnames
    assert_equal 2, @client.state[:names].size # land-mine for future code (NAMES replies)
  end
  
  # ----- message testing -----
  
  def test_channel_message
    @plugin.channel_message '#chan', 'hello', @somenick
    assert_first_event ChannelMessageEvent, :who => 'somenick', :where => '#chan', :what => 'hello'
  end
  
  def test_private_message
    @plugin.private_message 'nick', 'hello', @somenick
    assert_first_event PrivateMessageEvent, :who => 'somenick', :where => 'nick', :what => 'hello', :context => :self
  end

  def test_channel_notice
    @plugin.channel_notice '#chan', 'hello', @somenick
    assert_first_event ChannelNoticeEvent, :who => 'somenick', :where => '#chan', :what => 'hello'
  end
  
  def test_channel_server_notice
    @plugin.channel_notice '#chan', 'hello', 'server.com'
    assert_first_event ChannelNoticeEvent, 
      :who => 'server.com', :where => '#chan', :what => 'hello', :context => :server
  end
    
  def test_private_notice
    @plugin.private_notice 'nick', 'hello', @somenick
    assert_first_event PrivateNoticeEvent, :who => 'somenick', :where => 'nick', :what => 'hello', :context => :self
  end

  def test_server_notice
    @plugin.private_notice 'nick', 'hello', 'server.com'
    assert_first_event PrivateNoticeEvent, 
      :who => 'server.com', :where => 'nick', :what => 'hello', :context => :server
  end

  ##### helpers #####

  def assert_first_event(event_class, required_hash)
    assert_event @client.state[:events].first, event_class, required_hash
  end

  def assert_event(event, event_class, required_hash)
    assert !event.nil?, "event of class #{event_class} expected"
    required_hash[:context] ||= nil
    assert_equal true, event.is_a?(Event), "the event should be an Event or subclass}"
    assert_equal true, event.is_a?(event_class), "event should be a #{event_class}"
    required_hash.each do |key,val|
      assert_equal val, event.send(key), "event.#{key} should be #{val}"
    end
  end

end