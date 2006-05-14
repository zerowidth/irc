class MockManager
  attr_reader :calls
  attr_accessor :events
  attr_accessor :client_running

  def initialize
    @calls = {}
    @events = []
    @client_running = false
  end

  def get_events param
    record_call :get_events, param
    @events
  end

  def client_running? client_name
    record_call :client_running?, client_name
    @client_running
  end
  
  # call recorder implementation
  def method_missing method_name, *args
    record_call method_name, args
  end
  def record_call(method,*args)
    @calls[method] ||= []
    @calls[method] << args
  end
end