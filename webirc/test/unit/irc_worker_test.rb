require File.dirname(__FILE__) + '/../test_helper'
require "#{RAILS_ROOT}/script/backgroundrb/lib/backgroundrb.rb" # hackery? reordered from generator?
require "#{RAILS_ROOT}/lib/workers/irc_worker"
require 'irc/client' # mock client, overrides lib/irc/client
require 'drb'
require 'logger'

class IrcWorker < BackgrounDRb::Rails
  attr_reader :work_thread, :client
end

class IrcWorkerTest < Test::Unit::TestCase
  fixtures :connection_prefs
    
  def setup
    @conn = connection_prefs(:quentin)
    @worker = IrcWorker.new(@conn.to_hash)
    @worker.client.state[:events] = []
    @worker.client.state[:nick] = 'nick'
  end
  
  def test_undumped
    assert IrcWorker.included_modules.include?(DRbUndumped)
  end
    
  def test_do_work_creates_client
    @worker.work_thread.join(0) # check for errors!
    assert_instance_of IRC::Client, @worker.client
    assert_equal @conn.to_hash, @worker.client.calls[:merge_config][0][0], 'worker should have merged config'
    # worker doesn't start the client here, that's left up to the controller to do.
    # having the controller call connect makes catching exceptions easier.
  end
  
  def test_events
    @worker.client.state[:events] = []
    5.times { @worker.client.state[:events] << IRC::Event.new }
    assert_equal @worker.client.state[:events], @worker.events
  end
  
  def test_events_since
    @worker.client.state[:events] = []
    5.times { @worker.client.state[:events] << IRC::Event.new }
    last_id = @worker.client.state[:events][2].id
    assert_equal @worker.client.state[:events][3..4], @worker.events_since(last_id)
  end
  
  def test_events_since_with_nil
    @worker.client.state[:events] = []
    5.times { @worker.client.state[:events] << IRC::Event.new }
    assert_equal 5, @worker.events_since(nil).size
  end
  
  def test_state
    state = {:foo => 'bar', :baz => 'mumble'}
    @worker.client.state = state
    assert_equal state, @worker.state
  end
  
  def test_autojoin
    @worker.autojoin('#chan')
    assert @worker.state[:topics].has_key?( '#chan' )
  end
  
  def test_connected
    @worker.work_thread.join # wait for the work thread to get started
    @worker.client.start
    assert @worker.connected?    
  end
  
  def test_start
    @worker.start
    assert @worker.client.calls[:start], 'client should have been started'
  end
  
  def test_quit
    @worker.quit
    assert @worker.client.calls[:quit]
    @worker.quit('reason')
    assert_equal ['reason'], @worker.client.calls[:quit].last
  end
  
  def test_add_event
    e = IRC::Event.new
    @worker.add_event e
    assert_equal e, @worker.events.last
  end
  
  def test_change_nick
    @worker.change_nick('newnick')
    assert_equal ['newnick'], @worker.client.calls[:change_nick].first
    @worker.change_nick()
    assert_equal [''], @worker.client.calls[:change_nick].last
  end
  
  def test_channel_message
    @worker.channel_message('#chan', 'msg')
    assert_equal ['#chan', 'msg'], @worker.client.calls[:channel_message].first
    assert_event @worker.events.last, IRC::ChannelMessageEvent,
      :who => 'nick', :where => '#chan', :what => 'msg', :context => :self
  end
  
  # and from here on out, the worker's done. it gives the client to the controllers,
  # and that's that.
  
  private
  
  def assert_event(event, event_class, required_hash)
    assert !event.nil?, "event of class #{event_class} expected"
    required_hash[:context] ||= nil
    assert event.is_a?(IRC::Event), "the event should be an Event or subclass}"
    assert_instance_of event_class, event, "event should be a #{event_class}"
    required_hash.each do |key,val|
      assert_equal val, event.send(key), "event.#{key} should be #{val}"
    end
  end
  
end
