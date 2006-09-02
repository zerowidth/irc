require File.dirname(__FILE__) + '/test_helper'



class BackgrounDRbTest < Test::Unit::TestCase
  
  def setup
    @middleman = BackgrounDRb::MiddleMan.new
    class << @middleman
      def cache_as(named_key, data=nil)
        if data
          cache(named_key, Marshal.dump(data))
          data
        elsif block_given?
          res = yield
          cache(named_key, Marshal.dump(res))
          res
        end  
      end

      def cache_get(named_key)
        if self[named_key]
          return Marshal.load(self[named_key])
        elsif block_given?
          self[named_key] = Marshal.dump(yield)
          return Marshal.load(self[named_key])
        else
          return nil    
        end     
      end
    end
  end  
  
  def test_new_worker
    job_key = @middleman.new_worker(:class => :test_worker,
                                   :args => {:foo => 'bar', :job => 1})
    assert_kind_of Integer, @middleman.get_worker(job_key).progress
    sleep 0.0001
    assert @middleman.get_worker(job_key).progress == 100
    assert_equal 32, job_key.length                               
    assert_equal 'bar', @middleman.get_worker(job_key).foo 
    assert_equal 1, @middleman.get_worker(job_key).job
    assert_equal 1, @middleman.jobs.keys.length
    assert_equal job_key, @middleman.timestamps.keys.first
    assert_kind_of Time, @middleman.timestamps[job_key]
    @middleman.delete_worker job_key
    assert_nil @middleman.get_worker(job_key) 
    assert_nil @middleman.timestamps[job_key]       
  end  
  
  def test_bracket_syntax
    @middleman[:foo] = {:bar => 'bar', :qux => 'qux'}
    @middleman[:bar] = Time.now
    
    assert_equal('bar', @middleman[:foo][:bar])
    assert_equal('qux', @middleman[:foo][:qux])
    assert_kind_of(Time, @middleman[:bar])
    assert_equal(2, @middleman.jobs.keys.length)
    assert(@middleman.timestamps.keys.include?(:foo))
    assert(@middleman.timestamps.keys.include?(:bar))
    @middleman.delete_worker(:foo)
    assert_equal(false, @middleman.timestamps.keys.include?(:foo))
    assert_equal(1, @middleman.jobs.keys.length)
    assert_nil(@middleman[:foo])
    @middleman.delete_worker(:bar)
    assert_nil(@middleman[:bar])
  end  
  
  def test_multiple_workers
    job1 = @middleman.new_worker(:class => :test_worker,
                                  :args => {:foo => 'bar1', :job => 1})
    job2 = @middleman.new_worker(:class => :test_worker,
                                  :args => {:foo => 'bar2', :job => 2})
    job3 = @middleman.new_worker(:class => :test_worker,
                                  :args => {:foo => 'bar3', :job => 3})   
    job4 = @middleman.new_worker(:class => :test_worker,
                                  :args => {:foo => 'bar4', :job => 4})
    assert_equal('bar1', @middleman[job1].foo) 
    assert_equal('bar2', @middleman[job2].foo) 
    assert_equal('bar3', @middleman[job3].foo) 
    assert_equal('bar4', @middleman[job4].foo)
    assert_equal(1, @middleman[job1].job) 
    assert_equal(2, @middleman[job2].job) 
    assert_equal(3, @middleman[job3].job) 
    assert_equal(4, @middleman[job4].job)                              
    assert_equal(4, @middleman.jobs.keys.length)
    assert_equal(4, @middleman.timestamps.keys.length)
    assert_equal(@middleman.jobs.keys, @middleman.timestamps.keys)
    @middleman.gc!(Time.now)
    assert_nil(@middleman[job1])                                                       
    assert_nil(@middleman[job2])   
    assert_nil(@middleman[job3])   
    assert_nil(@middleman[job4])
    assert_equal(0, @middleman.timestamps.keys.length)
  end  
  
  def test_caching
    @middleman.cache_as(:foo, {:data => "Cached Data"})
    assert_equal("Cached Data", @middleman.cache_get(:foo)[:data])
    assert Time.now > @middleman.timestamps[:foo]
    @middleman.delete_cache(:foo)
    assert_nil(@middleman.cache_get(:foo))
    assert_equal("New Cached Data", 
                 @middleman.cache_get(:foo) { {:data => "New Cached Data"} }[:data])
  end  
  
  def test_duplicate_key_error
    @middleman.new_worker(:class => :test_worker,
                           :args => {:job => "first with :key"},
                           :job_key => :key)
    assert_equal("first with :key", @middleman[:key].job)                       
    assert_raise(BackgrounDRbDuplicateKeyError) do
      @middleman.new_worker(:class => :test_worker,
                             :args => {:job => "second with :key"},
                             :job_key => :key)
    end  
    assert_equal("first with :key", @middleman[:key].job)  
    assert_nothing_raised(BackgrounDRbDuplicateKeyError) do
      @middleman.new_worker(:class => :test_worker,
                             :args => {:job => "first with :new_key"},
                             :job_key => :new_key)
    end  
    assert_equal("first with :new_key", @middleman[:new_key].job) 
    assert_raise(BackgrounDRbDuplicateKeyError) do
      @middleman.new_worker(:class => :test_worker,
                             :args => {:job => "second with :new_key"},
                             :job_key => :new_key)
    end
    assert_equal("first with :new_key", @middleman[:new_key].job)
  end  
end  