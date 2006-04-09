require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require File.expand_path(File.dirname(__FILE__) + "/../../plugins/statemanager")
require 'stubs/command_queue_stub'

class StateManagerPluginTests < Test::Unit::TestCase
  
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
      :events => {
        '#chan'=>[],
        '#chan2'=>[],
#        'somenick'=>['somenick']
      }
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
    
    @msg_welcome = Message.parse(':server.com 001 :Welcome to the network')
  end
  
  def test_registration
    # TODO test that this plugin registers for everything it should
  end

  # should change own nick in nick lists and add event
  def test_nick_when_self
    @plugin.nick(@msg_change_own_nick)
    assert_equal 'newnick', @state[:names]['#chan'][1]
    assert_event @state[:events]['#chan'].last, 
      :nickchange, :update, '#chan', 'nick', 'newnick', nil
  end
  
  # should update all instances of somenick with somenick2 and add event (one per chan)
  def test_nick_when_other
    @plugin.nick(@msg_change_other_nick)
    assert_equal 'somenick2', @state[:names]['#chan'][0]
    assert_equal 'somenick2', @state[:names]['#chan2'][2]
    assert_event @state[:events]['#chan'][0], 
      :nickchange, :update, '#chan', 'somenick', 'somenick2', nil
    assert_event @state[:events]['#chan2'][0], 
      :nickchange, :update, '#chan', 'somenick', 'somenick2', nil
    # TODO: private message gets updated with new name 
    # TODO: is this a good idea? might b0rk the front-end app?
#    assert @state[:names]['somenick2']
#    assert_equal nil, @state[:names]['somenick']
#    assert_equal 'somenick2', @state[:names]['somenick2'][0]
#    assert_event ....
  end

  def test_self_join
    @state[:names]['#chan'] = nil
    @state[:topics]['#chan'] = nil
    @state[:events]['#chan'] = nil
    @plugin.join(@msg_self_join)
    assert_equal [], @state[:names]['#chan']
    assert_equal '', @state[:topics]['#chan']
    assert_equal [], @state[:events]['#chan']
  end
  
  def test_other_join
    @plugin.join(@msg_other_join)
    assert_equal 3, @state[:names]['#chan'].size
    assert_event @state[:events]['#chan'].first, 
      :join, :update, '#chan', 'somedude', nil, '~someuser@server.com'
  end
  
  def test_self_part
    @plugin.part(@msg_self_part)
    assert_equal nil, @state[:names]['#chan']
    assert_equal nil, @state[:topics]['#chan']
    assert_equal nil, @state[:events]['#chan']
  end
  
  def test_other_part
    @plugin.part(@msg_other_part)
    assert_equal ['nick'], @state[:names]['#chan']
    # make sure he didn't leave the other channel!
    assert_equal ['nick', 'name2', 'somenick'], @state[:names]['#chan2']
    assert_event @state[:events]['#chan'][0], 
      :part, :server, '#chan', 'somenick', '~someuser@server.com', 'reason'
    assert_event @state[:events]['#chan'][1], 
      :part, :update, '#chan', 'somenick', '~someuser@server.com', 'reason'
  end
  
  def test_other_quit
    @plugin.quit(@msg_other_quit)
    assert_equal ['nick'], @state[:names]['#chan']
    assert_equal ['nick', 'name2'], @state[:names]['#chan2']
    assert_event @state[:events]['#chan'][0], 
      :quit, :server, '#chan', 'somenick', '~someuser@server.com', 'reason'
    assert_event @state[:events]['#chan'][1], 
      :quit, :update, '#chan', 'somenick', '~someuser@server.com', 'reason'
    assert_event @state[:events]['#chan2'][0], 
      :quit, :server, '#chan', 'somenick', '~someuser@server.com', 'reason'
  end
  
  def test_topic
    @plugin.m332(@msg_new_topic)
    assert_equal 'new topic', @state[:topics]['#chan']
    assert_event @state[:events]['#chan'][0],
      :topic, :server, '#chan', nil, nil, 'new topic'
    assert_event @state[:events]['#chan'][1],
      :topic, :update, '#chan', nil, nil, 'new topic'
  end
  
  def test_topic_change
    @plugin.topic(@msg_topic_change)
    assert_equal 'new topic', @state[:topics]['#chan']
    assert_event @state[:events]['#chan'][0],
      :topic, :server, '#chan', 'somenick', nil, 'new topic'
    assert_event @state[:events]['#chan'][1],
      :topic, :update, '#chan', 'somenick', nil, 'new topic'
  end
  
  def test_names
    assert_equal 2, @state[:names]['#chan'].size
    @plugin.m353(@msg_names_1)
    assert_equal 5, @state[:names]['#chan'].size
    assert_event @state[:events]['#chan'].last, 
      :names, :server, '#chan', nil, 'nick', 'one @two three'
    @plugin.m353(@msg_names_2)
    assert_equal 8, @state[:names]['#chan'].size
    assert_event @state[:events]['#chan'].last, 
      :names, :server, '#chan', nil, 'nick', '@four five @six'
  end
  
  def test_end_of_names
    @plugin.m366(@msg_end_of_names)
    assert_event( @state[:events]['#chan'][0], 
      :end_of_names, :update, '#chan', nil, 'nick', 'end of names list')
  end
  
  # make sure an event queue doesn't get any larger than it's supposed to
  def test_max_queue_size
    (StateManagerPlugin::MAX_EVENT_QUEUE_SIZE+100).times do 
      @plugin.m332(@msg_new_topic)
    end    
    assert_equal StateManagerPlugin::MAX_EVENT_QUEUE_SIZE, @state[:events]['#chan'].size
  end
  
  # plugin should autorejoin any channels it was in
  def test_autorejoin
    # test without any channels first
    topics = @state[:topics]
    @state[:topics] = []
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
  
  def assert_event(event, type, category, where, from, to, data)
    assert_equal true, event.is_a?(Event), "event must exist"
    assert_equal type, event.type, "event.type should be #{type}"
    assert_equal category, event.category, "event.category should be #{category}"
    assert_equal from, event.from, "event.from should be #{from}"
    assert_equal to, event.to, "event.to should be #{to}"
    assert_equal data, event.data, "event.data should be #{data}"
  end
  
end