require File.expand_path(File.dirname(__FILE__) + "/../test-helper")

require 'irc/event'

include IRC

class EventTests < Test::Unit::TestCase
  
  def test_event_creation
    e = Event.new(:who, :where, :what)
    now = Time.now
    assert_equal :who, e.who
    assert_equal :where, e.where
    assert_equal :what, e.what
    assert_equal :what, e.data # alias
    assert (now - e.time) <= 1 # shouldn't take more'n a second!
    assert e.id
  end
  
  def test_sequential_id
    one = Event.new(nil, nil, nil)
    two = Event.new(nil, nil, nil)
    assert one.id == two.id - 1
  end
  
end