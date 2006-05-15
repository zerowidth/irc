class MockProxy
  include CallRecorder

  attr_accessor :running

  def initialize
    @events = []
    @running = false
  end
  
  def events
    record_call :events
    @events
  end
  def add_event(event)
    record_call :add_event, event
    @events << event
  end
  
  def start
    record_call :start
    @running = true
  end
  
  def quit(reason=nil)
    record_call :quit, reason
    @running = false
  end
  
  def running?
    record_call :running?
    @running
  end
  
  def set_state(hash)
    @state = hash
  end
  
  def state(key)
    record_call :state, key
    @state ||= {}
    @state[key]
  end

end