# initial code found on http://rubygarden.org/ruby?MultiThreading
# CommandQueue implements a synchronized queue for use by the IRC client, plugins,
# and other classes. The client is the only thread that will be reading data from
# the queue, but all kinds of things will be adding stuff to it

require 'thread' # has Mutex, etc.

module IRC

class CommandQueue
  def initialize
    @q     = []
    @mutex = Mutex.new
    @cond  = ConditionVariable.new
    @dequeue_mutex = Mutex.new
  end

  def add(*elems) # renamed from enqueue for readability
    @mutex.synchronize do
      @q.push *elems
      @cond.signal
    end
  end

  def dequeue
    @dequeue_mutex.synchronize do
      @mutex.synchronize do
        @cond.wait(@mutex) while @q.empty?
        return @q.shift
      end
    end
  end

  def empty?
    @mutex.synchronize do
      return @q.empty?
    end
  end
end

end # module