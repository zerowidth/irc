# synchronized hash:
# this is used to store state, but prevent the clients that are changing
# the state from stepping on each other.

# I'd have written tests for this if I could reliably simulate race conditions...
require 'thread'

class SynchronizedHash < Hash
  def initialize(*args)
    super(args)
    @mutex = Mutex.new
  end
  
  def [](key)
    @mutex.synchronize do
      super(key)
    end
  end
  
  def []=(key, val)
    @mutex.synchronize do
      super(key,val)
    end
  end
  
end