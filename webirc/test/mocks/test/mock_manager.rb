class MockManager
  include CallRecorder

  def initialize(proxy)
    @proxy = proxy
  end
  
  def client(name)
    record_call :client, name
    @proxy
  end
  
end