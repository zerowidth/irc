
class Worker
  include DRbUndumped

  attr_accessor :text

  def initialize(options={})
    @progress = 0
    @text = options[:text]
    @logger = BACKGROUNDRB_LOGGER
    start_working
  end

  def start_working
    # Fake work loop here to demo progress bar.
    Thread.new do
      while @progress < 100
        sleep rand / 2
        a = [1,3,5,7]
        @progress += a[rand(a.length-1)]
        if @progress >= 100
          @progress = 100
          @text = @text.upcase + " : object_id:" + self.object_id.to_s
        end
      end
    end
  end

  def progress
    @logger.debug "#{self.object_id} : #{self.class} progress: #{@progress}"
    @progress
  end
end
