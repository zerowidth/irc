require File.expand_path(File.dirname(__FILE__) + "/../test_helper")

require 'notification'

class NotificationTest < Test::Unit::TestCase
  include IRC

  class A
    include Notification
    def do_something
      notify :something
    end
    def do_other
      notify :other
    end
    def do_threaded
      threaded_notify :threaded
    end
    def do_unhandled
      notify :unhandled
    end
  end
  
  class B
    attr_reader :calls
    def initialize
      @calls = []
    end
    def something
      @calls << :something
    end
    def other
      @calls << :other
    end
    def threaded
      @calls << :threaded
      sleep Notification::THREAD_READY_WAIT
    end
    def catchall
      @calls << :catchall
    end
  end
  
  class ExceptionThrower
    def something
      raise 'kaboom'
    end
  end
  
  # triggered by A
  class SleepyHandler
    def something
      sleep Notification::THREAD_READY_WAIT * 2
    end
    def other
    end
    def threaded
    end
  end
  
  class LoggingClass
    include Notification
    attr_reader :log
    def initialize
      @log = []
    end
    def info(msg)
      @log << msg
    end
    alias :warn :info
    alias :error :info
    def logger
      self
    end
    def go
      notify :something
    end
    def go_threaded
      threaded_notify :something
    end
  end
  
  def setup
    @a = A.new
    @b = B.new
    @s = SleepyHandler.new
    @et = ExceptionThrower.new
  end
  
  def test_add_delete_observer
    @a.add_observer @b, :something, :other
    assert_equal @b, @a.observers[:something].first, 'b should be observing a for :something'
    @a.delete_observer @b
    assert_equal 0, @a.observers[:something].size, 'b should no longer be observing :something'
    assert_equal 0, @a.observers[:other].size, 'b should no longer be observing :other'
  end
  
  def test_basic_callback
    @a.add_observer @b, :something
    @a.do_something
    assert_equal :something, @b.calls.first
  end
  
  def test_multiple_callbacks
    @a.add_observer @b, :something, :other
    @a.do_something
    @a.do_other
    assert_equal 2, @b.calls.size
    assert_equal :something, @b.calls.first
    assert_equal :other, @b.calls.last
  end
  
  def test_all_callback
    @a.add_observer @b, :all
    @a.do_something
    assert_equal :something, @b.calls.first
  end
  
  def test_double_registration_called_once
    @a.add_observer @b, :something
    @a.add_observer @b, :something
    @a.add_observer @b, :other, :other
    @a.do_something
    assert_equal 1, @b.calls.size
    @a.do_other
    assert_equal 2, @b.calls.size
  end
  
  def test_threaded_notify
    @a.add_observer @b, :threaded
    @a.add_observer @b, :something
    t = Thread.new { @a.do_threaded; @a.do_something }
    t.join(0.01)
    assert_false t.alive?, 'do_threaded call should be complete!'
    
    # wait for it to finish
    sleep Notification::THREAD_READY_WAIT + 0.01
    assert_equal 2, @b.calls.size
    
    # make sure the janitor thread exits
    t = Thread.new { @a.janitor_thread.join }
    t.join Notification::THREAD_READY_WAIT * 2
    assert_false @a.janitor_thread.alive?, 'janitor thread should have exited!'
  end
  
  def test_multi_threaded_notify
    @a.add_observer @b, :threaded
    @a.do_threaded
    @a.do_threaded # twice
    assert_equal 2, @a.notify_threads.size, 'should be two notify threads running'
  end
  
  # added this to better handle multi-threaded apps
  # specifically, the general client thread and the connection data handler
  # thread were accessing notification at the same time with no controls
  def test_notification_synchronization
    # s handles something and threaded callbacks
    @a.add_observer @s, :all
    @a.do_other # make sure the mutex gets initialized
    sleepy_call = Thread.new { @a.do_something }
    # there's a potential race condition between ^^ and vv . if necessary, join sleepy_call...
    fast_call = Thread.new { @a.do_other } # should have to wait!
    fast_call.join(Notification::THREAD_READY_WAIT) # half the waiting time
    assert fast_call.alive?, 'fast call should have died!'
  end
  def test_threaded_notification_synchronization
    @a.add_observer @s, :all
    @a.do_other # make sure the mutex gets initialized
    sleepy_call = Thread.new { @a.do_something }
    fast_call = Thread.new { @a.do_threaded } # should have to wait!
    fast_call.join(Notification::THREAD_READY_WAIT) # half the sleepy time
    assert fast_call.alive?, 'fast call should not have ended yet!'
  end
  
  # notifications that threw exceptions weren't returning correctly. tested here:
  def test_failed_notifications_return_successfully
    @a.add_observer @et, :something
    t = Thread.new { @a.do_something }
    assert_nothing_raised { t.join }
  end
  
  def test_logging
    l = LoggingClass.new
    e = ExceptionThrower.new
    l.add_observer e, :something
    l.go_threaded
    l.janitor_thread.join
    assert_false l.log.empty?, 'log should not be empty'
  end
  
  def test_no_failures_when_no_logger
    e = ExceptionThrower.new
    @a.add_observer e, :something
    @a.do_something
  end

end