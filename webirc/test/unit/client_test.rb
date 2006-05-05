require File.dirname(__FILE__) + '/../test_helper'

require 'drb'
require 'irc/event'
require 'test/mocks/mockmanager' # mock bot manager

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
  
end
