module IRC
  
  # how long the thread handler waits for threads to finish
  THREAD_JOIN_WAIT = 0.05
  
  class ThreadManager
    def initialize
      @threads = []
    end
    def new_thread(*args, &block)
      t = Thread.new(*args, &block)
      @threads << t
      t # return the thread in case anyone else wants to keep track of it
    end
    def check_threads
      @threads.each do |t|
        joined = t.join(THREAD_JOIN_WAIT)
        @threads.delete(t) if joined
      end
    end
    def kill_all
      @threads.each do |t|
        t.kill
      end
    end
    def empty?
      @threads.empty?
    end
  end
  
end