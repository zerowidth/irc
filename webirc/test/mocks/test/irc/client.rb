# full drop-in replacement for IRC::Client. 
module IRC
  class Client
    cattr_accessor :logger
    include CallRecorder
    attr_accessor :config, :state
    def initialize
      @config = {}
      @state = {}
      @connected = false
    end
    def start
      record_call :start
      @connected = true
    end
    def connected?
      @connected
    end
    def connected=(bool)
      @connected = bool
    end
  end
  
end