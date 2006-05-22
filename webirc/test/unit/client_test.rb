require File.dirname(__FILE__) + '/../test_helper'

require 'drb'
require 'irc/event'
#require 'mockmanager' # mock bot manager

class ClientTest < Test::Unit::TestCase
  
  fixtures :users

  def setup
    @proxy = MockProxy.new
    @manager = MockManager.new @proxy
    DRb.start_service(Client.drb_uri, @manager)
    
    @client = Client.new(:client_name)
  end
  
  def teardown
    DRb.stop_service
  end

  def test_client_retrieves_proxy
    # this has already been called in setup
    assert @manager.calls[:client]
    assert_equal :client_name, @manager.calls[:client].first[0]
  end
  
  def test_events
    assert_equal [], @client.events, 'events should be an empty array'
    assert @proxy.calls[:events]
    @proxy.add_event IRC::Event.new # this should work!
    assert @client.events.size > 0
  end
  
  def test_events_since
    # add test data
    5.times do
      @proxy.add_event IRC::Event.new
    end
    
    # test base case
    assert_equal 5, @client.events.size, 'should be 5 events'
    
    # pretend we've already seen the first event
    events_since_first = @client.events_since(@proxy.events.first.id)
    assert_equal 4, events_since_first.size, 'should have only found 4 events'
    assert events_since_first.first.id > @proxy.events.first.id, 'should have excluded the first event'

    # pretend we haven't seen any of the current events that are out there
    events_since_before_first = @client.events_since(@proxy.events.first.id - 1)
    assert_equal 5, events_since_before_first.size, 'should have found all 5 events'
    
    # pretend we've seen all of the events
    events_since_last = @client.events_since(@proxy.events.last.id)
    assert_equal 0, events_since_last.size, 'should have found zero events'
  end

  def test_connected
    @client.connected? # make the call
    assert @proxy.calls[:running?], "should delegate :running? to proxy object"
  end
  
  def test_client_connect
    defaults = { :nick => 'nick', :realname => 'realname', :server => 'server', :port => 12345, :channel => '#chan'}
    connection_details = ConnectionPref.new defaults
    @client.connect connection_details
    # test that the manager received the correct messages:
    assert @proxy.calls[:merge_config], "proxy object should receive :merge_config"
    assert_equal defaults, @proxy.calls[:merge_config].first[0], "merge config should receive config hash"
    assert @proxy.calls[:start], "proxy should receive :start"
  end
  
  def test_client_quit
    @proxy.running = true
    @client.quit
    assert @proxy.calls[:quit], 'proxy should receive :quit'
    assert @manager.calls[:remove_client], 'manager should be asked to remove the client'
    assert_equal :client_name, @manager.calls[:remove_client].first[0]
  end
  
  def test_add_event
    @client.add_event(:event) # doesn't really matter what the event is, just add it!
    assert @proxy.calls[:add_event], "should receive :add_event"
    assert_equal :event, @proxy.calls[:add_event].first[0], "should receive the event as an argument"
  end
  
  def test_add_command
    @client.add_command(:command)
    assert @proxy.calls[:add_command], "should receive :add_command"
    assert_equal :command, @proxy.calls[:add_command].first[0], "should receive the command as an argument"
  end
  
  def test_state
    @proxy.set_state :foo=>'foo'
    assert_equal 'foo', @client.state(:foo)
  end
  
  def test_client_for
    c = Client.for(users(:quentin))
    assert @manager.calls[:client]
    assert_equal users(:quentin).id, @manager.calls[:client][1][0]
    assert_kind_of Client, c
  end
  
end
