require File.expand_path(File.dirname(__FILE__) + "/../test-helper")

require 'irc/event'

include IRC

class EventTests < Test::Unit::TestCase
  
  def test_factory
    # new_event( type, category, where, from, to, data )
    e = EventFactory.new_event( :sometype, :somecategory, :where, :from, :to, :data )
    now = Time.now
    assert_equal :sometype, e.type
    assert_equal :somecategory, e.category
    assert_equal :where, e.where
    assert_equal :from, e.from
    assert_equal :to, e.to
    assert_equal :data, e.data
    assert (now - e.time) <= 1 # shouldn't take more'n a second
    assert e.id # careful... this better be overridden!
    e2 = EventFactory.new_event( nil, nil, nil, nil, nil, nil )
    assert 1, e2.id - e.id # sequential ids from generator
  end
  
end