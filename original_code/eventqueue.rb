require 'monitor'

module IRC
  
  class Event
    attr_reader :sender, :event, :data
    def initialize(sender,event,data=nil)
      @sender = sender
      @event = event
      @data = data
    end
  end
  
  class EventQueue
    
  end
  
end