class TestWorker
  include DRbUndumped
  
  attr_accessor :foo
  attr_accessor :job
  
  def initialize(options={})
    @foo = options[:foo]
    @job = options[:job]
    @progress = 0
    start_working
  end
  
  def start_working
    # Fake work loop here to demo progress bar.
    Thread.new do
      while @progress < 100
        @progress += 1
      end
    end  
  end
  
  def progress
    @progress
  end      
end  
