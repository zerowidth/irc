require File.dirname(__FILE__) + '/../test_helper'

require 'drb'
require 'irc/event'
require 'mockmanager' # mock bot manager

class ClientTest < Test::Unit::TestCase

  def setup
    @manager = MockManager.new
    DRb.start_service(Client.drb_uri, @manager)
    @client = Client.new :client_name # uses drb
  end
  
  def teardown
    DRb.stop_service
  end

  def test_events
    assert_equal [], @client.events, 'events should be an empty array'
    assert @manager.calls[:get_events] && @manager.calls[:get_events].size > 0
    @manager.events << IRC::Event.new(:who, :where, :what)
    assert @client.events.size > 0
  end
  
  def test_events_since
    5.times do
      @manager.events << IRC::Event.new(nil, nil, nil)
    end
    assert_equal 5, @client.events.size, 'should be 6 events'
    events_since_first = @client.events_since(@manager.events.first.id)
    assert_equal 4, events_since_first.size, 'should have only found 4 events'
    assert events_since_first.first.id > @manager.events.first.id, 'should have excluded the first event'
  end
  
  def test_connected
    @client.connected? # make the call
    assert @manager.calls[:client_running?].size > 0, "should delegate :client_running? to bot manager"
  end
  
  def test_client_connect
    defaults = { :nick => 'nick', :realname => 'realname', :server => 'server', :port => 12345, :channel => '#chan'}
    connection_details = Connection.new defaults
    @client.connect connection_details
    # test that the manager received the correct messages:
    assert @manager.calls[:merge_config], "manager should receive :merge_config"
    assert_equal :client_name, @manager.calls[:merge_config].first.flatten[0], "client name must be sent"
    assert_equal defaults, @manager.calls[:merge_config].first.flatten[1], "manager should receive hash"
    assert @manager.calls[:start_client], "manager should receive :start_client"
    assert_equal :client_name, @manager.calls[:start_client].first.flatten[0]
  end
  
  def test_client_shutdown
    @client.shutdown
    assert @manager.calls[:shutdown]
    assert_equal :client_name, @manager.calls[:shutdown].first.flatten[0], "client name is required"
  end
  
  def test_add_event
    @client.add_event(:event) # doesn't really matter what the event is, just add it!
    assert @manager.calls[:add_event], "should receive :add_event"
    assert_equal :client_name, @manager.calls[:add_event].first.flatten[0], "client name is required"
    assert_equal :event, @manager.calls[:add_event].first.flatten[1], "should receive the event as an argument"
  end
  
  def test_add_command
    @client.add_command(:command)
    assert @manager.calls[:add_command], "should receive :add_command"
    assert_equal :client_name, @manager.calls[:add_command].first.flatten[0], "client name is required"
    assert_equal :command, @manager.calls[:add_command].first.flatten[1], "should receive the event as an argument"
  end
  
end
