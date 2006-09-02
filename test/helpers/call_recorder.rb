# implements basic call recorder functionality for testing
module CallRecorder
  attr_reader :calls

  def method_missing method_name, *args
    record_call method_name, args
  end

  def record_call(method,*args)
    @calls ||= {}
    @calls[method] ||= []
    @calls[method] << [args].flatten
  end
  
end