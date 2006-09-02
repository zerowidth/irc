require 'drb'
require 'digest/md5'
require 'thread'
# Set up BACKGROUNDRB_LOGGER to be the default logger for your worker
# objects. Use like: BACKGROUNDRB_LOGGER.warn("you've been warned")
# or BACKGROUNDRB_LOGGER.debug("debug info")
BACKGROUNDRB_LOGGER = Logger.new("#{RAILS_ROOT}/log/backgroundrb.log")

class BackgrounDRbDuplicateKeyError < Exception 
end

module BackgrounDRb

  class Rails
    include DRbUndumped
    
    # make your worker classes inherit from BackgrounDRb::Rails
    # to get access to all of your rails model classes. Doing it
    # this way also allows for very simple worker classes that
    # get threaded automatically.
    # class MyWorker < BackgrounDRb::Rails
    #   def do_work(args)
    #     # work done in here is already running inside of a
    #     # thread and gets called right away when you call
    #     # MiddleMan.new_worker from rails.
    #   end
    # end
    # doing it this way you also automatically get access to
    # the log via @logger
    def initialize(args)
      @logger = BACKGROUNDRB_LOGGER
      Thread.new { do_work(args) }
    end
    
  end  

  class MiddleMan
    include DRbUndumped
    
    # initialize @jobs as a Hash that holds a pool of all 
    # the running workers { job_key => running_worker_instance }
    # or can be used as a application wide cache with named keys
    # instead of randomly generated ones. @timestamps holds a 
    # hash of timestamps { job_key => timestamp }. So we can do 
    # timestamps and corelate them to workers for garbage 
    # collection when needed.
    def initialize
      @jobs = Hash.new
      @mutex = Mutex.new
      @timestamps = Hash.new
    end 

    # takes an opts hash with symbol keys. :class refers to 
    # the under_score version of the worker class you want to
    # instantiate. :job_key can be set to use a named key, if
    # no :job_key is given we generate one. :args can hold 
    # any kind of info you want to give to your worker class
    # when it gets initialized. since we use the []= method
    # that we have defined, timestamps are handled transparently.   
    def new_worker(opts={})
      @mutex.synchronize {
        job_key = opts[:job_key] || gen_key
        unless self[job_key]
          self[job_key] = instantiate_worker(opts[:class]).new(opts[:args])
          return job_key
        else
          raise ::BackgrounDRbDuplicateKeyError
        end    
      }
    end
    
    # delete a worker from the pool, also deletes the corresponding
    # entry in the @timestamps hash.
    def delete_worker(key)
      @mutex.synchronize {
        @jobs.delete(key)
        @timestamps.delete(key)
      }
    end
    alias :delete_cache :delete_worker

    # This method is used for caching arbitrary objects. Any object
    # that can be marshalled can be cached.
    def cache(named_key, object)
      @mutex.synchronize {
          self[named_key] = object
      }  
    end  

    # garbage collection method for cleaning out jobs
    # older then a certain amount of time. So you
    # can either make sure you always delete
    # your workers in rails when you are finished with them, 
    # or you can have a cron job run and call gc! with a time
    # to clean out all jobs older them that time. Call it
    # like this: MiddleMan.gc!(Time.now - 60*30). that will
    # clear out all jobs older then 30 minutes.
    def gc!(age)
      @timestamps.each do |job_key, timestamp|
        if timestamp < age
          delete_worker(job_key)
        end
      end  
    end  
    
    # retrieve handle on worker object with key. Can be called
    # with a MiddleMan[:job_key] syntax or with MiddleMan.get_worker(:job_key)
    def [](key)
      @jobs[key]
    end
    alias :get_worker :[]
     
    def []=(key, val)
      @jobs[key] = val
      @timestamps[key] = Time.now
    end  
    
    def jobs
      @jobs
    end  
    
    def timestamps
      @timestamps
    end
    
    private
      
    def instantiate_worker(klass)
      Object.const_get(klass.to_s.split('_').inject('') { |total,part| total << part.capitalize })
    end
    
    def gen_key
      begin
        key = Digest::MD5.hexdigest("#{inspect}#{Time.now}#{rand}")
      end until self[key].nil?
      key
    end
  end  

end