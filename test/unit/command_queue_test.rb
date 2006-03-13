require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/command_queue'

class CommandQueueTest < Test::Unit::TestCase
  include IRC
  
  def setup
    @cq = CommandQueue.new
  end
  
  def test_basic_queue_functions
    assert @cq.empty?
    @cq.add(:foo)
    assert_false @cq.empty?
    @cq.add(:bar)
    foo = @cq.dequeue()
    assert_equal :foo, foo
    @cq.add(:baz)
    bar = @cq.dequeue()
    assert_equal :bar, bar
    baz = @cq.dequeue()
    assert_equal :baz, baz
    assert @cq.empty?    
  end
  
  def test_condition_variable_waiting
    # a little more complicated: test how the dequeue waiting works
    # this told me how the client is going to have to handle the dequeue() calls
    # since it's completely blocking, with no timeouts.
    data = nil # set scope for data
    t = Thread.new { data = @cq.dequeue() } # should be a blocking call!
    assert_equal nil, data # shouldn't be set yet
    assert t.alive?
    @cq.add(:data) # throw something on the queue
    t.join(0.1) # join the thread, with timeout just in case
    assert_false t.alive?
    assert_equal :data, data
  end
  
end