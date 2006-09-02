# from http://www.sitharus.com/articles/2006/02/06/and-then-the-train-hits-you
# and http://ruby-doc.org/stdlib/libdoc/observer/rdoc/index.html

require 'monitor'

module Notification # originally named Observable, but there's a stdlib library...
  include MonitorMixin
  
  THREAD_READY_WAIT = 0.1 # seconds
  
  def add_observer(object, *events)
    if events.empty?
      STDERR.puts "warning: no callback events for #{object} specified!"
    end
    @observers ||= {}
    events.each do |event|
      event = event.to_sym
      @observers[event] ||= []
      @observers[event] << object unless @observers[event].include? object
    end
  end
  
  def delete_observer(object)
    @observers.each do |callback, observer_list|
      observer_list.delete(object)
    end
  end

  private
  
  def notify(event, *args)
    @notification_monitor ||= Monitor.new
    return unless @observers
    event = event.to_sym
    whom = observers_for(event)
    @notification_monitor.synchronize do
      begin
        whom.each do |obj|
          obj.send(event, *args) if obj.respond_to? event
        end
      rescue => e
        if defined?(logger)
          logger.warn "exception caught in notification handler thread: #{e.inspect}"
          e.backtrace.each { |bt| logger.warn bt }
        end
      end
    end
  end
  
  def threaded_notify(event, *args)
    return unless @observers
    event = event.to_sym
    whom = observers_for(event)
    
    if !@notify_threads
      @notify_threads = []
      @notify_threads.extend(MonitorMixin)
    end
    @notification_monitor ||= Monitor.new
    @notification_monitor.synchronize do # protection from external clients
      @notify_threads.synchronize do # protection for the janitor thread
        whom.each do |obj|
          if obj.respond_to? event
            @notify_threads << Thread.new { obj.send(event, *args) }
          end
        end
      end
    end
    @janitor_thread = Thread.new { notify_janitor } unless @janitor_thread and @janitor_thread.alive?
  end

  def notify_janitor
    until @notify_threads.empty? do
      # synchronized so weirdness doesn't happen when another notification is going on
      @notify_threads.synchronize do
        @notify_threads.each do |thread| 
          begin
            # join up with threads temporarily so exceptions get logged
            thread.join(0) 
          rescue => e
            if defined?(logger)
              logger.warn "exception caught in threaded notification cleanup thread: #{e.inspect}"
              e.backtrace.each { |bt| logger.warn bt }
            end
            @notify_threads.delete(thread) # might cause weirdness, but only want to see an error once!
          end
        end
        
        # only do this directly after all threads are joined
        # delete any threads that are done
        @notify_threads.delete_if {|thread| not thread.alive?}
      end

      sleep(THREAD_READY_WAIT) unless @notify_threads.empty? # no wheel-spinning allowed, and no unnecessary sleeping!
    end # loop
  end
  
  def observers_for(event)
    whom = []
    whom += @observers[event] if @observers[event]
    whom += @observers[:all] if @observers[:all]
    whom.uniq
  end
  
end