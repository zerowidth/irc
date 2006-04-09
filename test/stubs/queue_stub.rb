class QueueStub
  attr_reader :queue
  def initialize
    @queue = []
  end

  def <<(*elems)
    @queue.push(*elems)
  end

  def dequeue
    # client testing will use the full-on CommandQueue
    raise "don't call this if you're not the client!"
  end

  def empty?
    @queue.empty?
  end
  
end