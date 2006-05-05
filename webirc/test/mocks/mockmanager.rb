class MockManager
  attr_reader :calls
  attr_accessor :events
  def initialize
    @calls = {}
    @events = []
  end
  def get_events param
    record_call :get_events, param
    @events
  end
  def method_missing method_name, *args
    record_call method_name, args
  end
  def record_call(method,*args)
    @calls[method] ||= []
    @calls[method] << args
  end
end