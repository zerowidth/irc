require 'helpers/call_recorder'

class ClientStub
  include CallRecorder
  attr_accessor :config, :state
  def initialize
    @config = {}
    @state = {}
  end
  
  # recording stubs
  def connected
    record_call :connected
  end
  def disconnected
    record_call :disconnected
  end
  def data(data)
    record_call :data, data
  end
  
  # commands
  def send_raw(data)
    record_call :send_raw, data
  end
  def change_nick(newnick)
    record_call :change_nick, newnick    
  end
  
end