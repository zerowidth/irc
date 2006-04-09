# event types:
# type          category        where   from        to        data
# -----------------------------------------------------------------------------
# :motd         :servermessage  nil                           motd string
# :nickchange   :update         chan/   old nick    new nick  none
#                               nick
# :join         :update         chan    nick        nil       ~user@host
# :names        :servermessage  chan    nil         nick      nick list
# :end_of_names :update         chan    nil         nick      end of list (server message)

# event types are implemented as a class hierarchy. Event#initialize sets the id and
# the timestamp.

module IRC
  
  # Event is an abstract IRC event. This is used by the StateManager plugin to keep a log
  # of events for use by external clients (e.g. Rails app).
  class Event
    attr_reader :id, :time
    attr_accessor :who, :where, :what
    alias :data :what # sometimes this makes more sense (semantically)
    
    def initialize(who, where, what)
      @id, @time = Event.new_instance_info
      @who = who
      @where = where
      @what = what
    end
    
    private
    
    # returns a new id and timestamp. class method so instances aren't dragging it around.
    def self.new_instance_info
      @@id ||= 0
      @@id += 1
      [@@id, Time.now]
    end
  end  

  
  # individual events
  
  class TopicEvent < Event; end # topic change in a channel, or when joining
    
  class JoinEvent < Event; end # joining a channel
  class PartEvent < Event; end # leaving a channel
  class QuitEvent < Event; end # quitting the server
    
  class NickChangeEvent < Event; end # self nick change
    
  class NameListEvent < Event; end # server is listing names in a chan
  class EndOfNamesEvent < Event; end # server is done listing names in a chan
  
end
