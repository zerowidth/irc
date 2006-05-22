require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require "irc/plugins/statemanager"
require 'stubs/queue_stub'

class StateManagerPluginTests < Test::Unit::TestCase
  
  include IRC
  
  def setup
    @queue = QueueStub.new
    @config = {}
    @state = {
      :nick => 'nick',
      :topics => {
        '#chan' => 'chan topic',
        '#chan2' => 'chan2 topic',
#        'somenick' => '' # TODO change this to 'private conversation with ...'
      },
      :names => {
        '#chan'=>['somenick', 'nick'], # has own nick!
        '#chan2' => ['nick', 'name2', 'somenick'], 
#        'somenick' => ['somenick'] # private message, hence the key
      },
      :events => []
    }
    
    @plugin = StateManagerPlugin.new(@queue, @config, @state)
    
    @msg_change_own_nick = Message.parse(':nick!~user@server.com NICK :newnick')
    @msg_change_other_nick = Message.parse(':somenick!~someuser@server.com NICK :somenick2')
    
    @msg_self_join = Message.parse(':nick!~user@server.com JOIN #chan')
    @msg_other_join = Message.parse(':somedude!~someuser@server.com JOIN #chan')
    
    @msg_self_part = Message.parse(':nick!~user@server.com PART #chan :reason')
    @msg_other_part = Message.parse(':somenick!~someuser@server.com PART #chan :reason')
    @msg_other_quit = Message.parse(':somenick!~someuser@server.com QUIT :reason')

    @msg_new_topic = Message.parse(':bigfeh.com 332 nick #chan :new topic')
    @msg_topic_change = Message.parse(':somenick!~someuser@server.com TOPIC #chan :new topic')
    
    @msg_names_1 = Message.parse(':server.com 353 nick @ #chan :one @two three')
    @msg_names_2 = Message.parse(':server.com 353 nick @ #chan :@four five @six')
    @msg_end_of_names = Message.parse(':server.com 366 nick #chan :end of names list')
    
    @msg_privmsg = Message.parse(':somenick!~someuser@server.com PRIVMSG #chan :hello')
    @msg_privmsg_private = Message.parse(':somenick!~someuser@server.com PRIVMSG nick :hello')
    @msg_privmsg_action = Message.parse(":somenick!~someuser@server.com PRIVMSG #chan :\001ACTION hello\001")
    
    @msg_notice = Message.parse(':somenick!~someuser@server.com NOTICE #chan :hello')
    @msg_notice_private = Message.parse(':somenick!~someuser@server.com NOTICE nick :hello')
    @msg_notice_server = Message.parse(':server.com NOTICE nick :hello')
    
    @msg_welcome = Message.parse(':server.com 001 :Welcome to the network')
    
    @msg_unknown = Message.parse(':server.com 210 :RPL_TRACERECONNECT is unused')
  end
  
  def test_registration
    # TODO test that this plugin registers for everything it should
  end

  # should change own nick in nick lists and add event
  def test_nick_when_self
    @plugin.nick(@msg_change_own_nick)
    assert_equal 'newnick', @state[:names]['#chan'][1]
    # should be an event listed in every channel
    assert_event @state[:events].last, NickChangeEvent,
      :who => 'nick', :where => '#chan', :what => 'newnick', :context => :self
    assert_event @state[:events].first, NickChangeEvent,
      :who => 'nick', :where => '#chan2', :what => 'newnick', :context => :self
  end
  
  # should update all instances of somenick with somenick2 and add event (one per chan)
  def test_nick_when_other
    @plugin.nick(@msg_change_other_nick)
    assert_equal 'somenick2', @state[:names]['#chan'][0]
    assert_equal 'somenick2', @state[:names]['#chan2'][2]
    # event should exist for all current channels
    assert_event @state[:events][1], NickChangeEvent, 
      :who => 'somenick', :where => '#chan', :what => 'somenick2', :context => nil
    assert_event @state[:events][0], NickChangeEvent, 
      :who => 'somenick', :where => '#chan2', :what => 'somenick2', :context => nil

    # TODO: private message gets updated with new name? 
    # TODO: is this a good idea? might b0rk the front-end app, by changing tab title or anything
  end

  def test_self_join
    @state[:names]['#chan'] = nil
    @state[:topics]['#chan'] = nil
    @state[:events] = []
    @plugin.join(@msg_self_join)
    assert_equal [], @state[:names]['#chan']
    assert_equal '', @state[:topics]['#chan']
    assert_equal [], @state[:events], 'no new events should be added'
  end
  
  def test_other_join
    @plugin.join(@msg_other_join)
    assert_equal 3, @state[:names]['#chan'].size
    assert_event @state[:events].first, JoinEvent, 
      :who => 'somedude', :where => '#chan', :what => '~someuser@server.com', :context => nil
  end
  
  def test_self_part
    @plugin.part(@msg_self_part)
    assert_equal nil, @state[:names]['#chan']
    assert_equal nil, @state[:topics]['#chan']
    assert_event @state[:events].first, PartEvent, 
      :who => 'nick', :where => '#chan', :what => ["~user@server.com", "reason"], :context => :self
  end
  
  def test_other_part
    @plugin.part(@msg_other_part)
    assert_equal ['nick'], @state[:names]['#chan']
    # make sure he didn't leave the other channel!
    assert_equal ['nick', 'name2', 'somenick'], @state[:names]['#chan2']
    assert_event @state[:events].first, PartEvent, 
      :who => 'somenick', :where => '#chan', :what => ['~someuser@server.com', 'reason'] # extra info
  end
  
  def test_other_quit
    @plugin.quit(@msg_other_quit)
    assert_equal ['nick'], @state[:names]['#chan']
    assert_equal ['nick', 'name2'], @state[:names]['#chan2']
    assert_event @state[:events].last, QuitEvent, 
      :who => 'somenick', :where => '#chan', :what => ['~someuser@server.com', 'reason'] # extra info
    assert_event @state[:events].first, QuitEvent, 
      :who => 'somenick', :where => '#chan2', :what => ['~someuser@server.com', 'reason']
  end
  
  def test_topic
    @plugin.m332(@msg_new_topic)
    assert_equal 'new topic', @state[:topics]['#chan']
    assert_event @state[:events].first, TopicEvent, 
      :who => nil, :where => '#chan', :what => 'new topic'
  end
  
  def test_topic_change
    @plugin.topic(@msg_topic_change)
    assert_equal 'new topic', @state[:topics]['#chan']
    assert_event @state[:events].first, TopicEvent, 
      :who => 'somenick', :where => '#chan', :what => 'new topic'
  end
  
  def test_names
    assert_equal 2, @state[:names]['#chan'].size
    @plugin.m353(@msg_names_1)
    assert_equal 5, @state[:names]['#chan'].size
    # RPL_NAMREPLY includes the user's nickname, but ignore it. 
    # this should set [:who] to :server, so it's clear that it's a server message
    assert_event @state[:events].last, NameListEvent, 
      :who => 'server.com', :where => '#chan', :what => 'one @two three', :context => :server
    @plugin.m353(@msg_names_2)
    assert_equal 8, @state[:names]['#chan'].size
    assert_event @state[:events].last, NameListEvent, 
      :who => 'server.com', :where => '#chan', :what => '@four five @six', :context => :server
  end
  
  def test_end_of_names
    @plugin.m366(@msg_end_of_names)
    assert_event @state[:events].first, EndOfNamesEvent, 
      :who => 'server.com', :where => '#chan', :what => 'end of names list', :context => :server
  end
  
  def test_privmsg
    @plugin.privmsg(@msg_privmsg)
    assert_event @state[:events].first, PrivMsgEvent, 
      :who => 'somenick', :where => '#chan', :what => 'hello'
  end
  
  def test_private_privmsg
    @plugin.privmsg(@msg_privmsg_private)
    assert_event @state[:events].first, PrivMsgEvent, 
      :who => 'somenick', :where => 'nick', :what => 'hello', :context => :self
  end
  
  def test_privmsg_with_action
    @plugin.privmsg(@msg_privmsg_action)
    assert_event @state[:events].first, PrivMsgEvent, 
      :who => 'somenick', :where => '#chan', :what => "\001ACTION hello\001"
  end
  
  def test_notice
    @plugin.notice(@msg_notice)
    assert_event @state[:events].first, NoticeEvent, 
      :who => 'somenick', :where => '#chan', :what => 'hello', :context => nil
  end
  
  def test_private_notice
    @plugin.notice(@msg_notice_private)
    assert_event @state[:events].first, NoticeEvent, 
      :who => 'somenick', :where => 'nick', :what => 'hello', :context => :self
  end
  
  def test_server_notice
    @plugin.notice(@msg_notice_server)
    assert_event @state[:events].first, NoticeEvent, 
      :who => 'server.com', :where => 'nick', :what => 'hello', :context => :server
  end
  
  def test_catchall
    @plugin.catchall(@msg_unknown)
    assert_event @state[:events].first, UnknownServerEvent, 
      :who => 'server.com', :where => "nick", :what => "RPL_TRACERECONNECT is unused", :context => :server
  end

  # make sure an event queue doesn't get any larger than it's supposed to
  def test_max_queue_size
    # make sure the max size got set first (should be a default in the plugin!)
    assert @config[:max_event_queue_size]
    (@config[:max_event_queue_size]+100).times do 
      @plugin.m332(@msg_new_topic)
    end    
    assert_equal @config[:max_event_queue_size], @state[:events].size
  end

  # plugin should autorejoin any channels it was in if it reconnects
  def test_autorejoin
    # test without any channels first
    topics, @state[:topics] = @state[:topics], [] # save 'em for a minute
    @plugin.m001(@msg_welcome)
    assert @queue.empty?
    
    # now with two channels
    @state[:topics] = topics
    @plugin.m001(@msg_welcome)
    # should be two join commands on the queue now
    assert JoinCommand, @queue.queue[0].class
    assert JoinCommand, @queue.queue[0].class
  end
  
  ##### helpers  
  
  def assert_event(event, event_class, required_hash)
    assert_equal true, event.is_a?(Event), "the event should be an Event or subclass}"
    assert_equal true, event.is_a?(event_class), "event should be a #{event_class}"
    required_hash.each do |key,val|
      assert_equal val, event.send(key), "event.#{key} should be #{val}"
    end
  end
  
end