# event types are implemented as a class hierarchy. Event#initialize sets the id and
# the timestamp.

# event.who should be one of three things: a nickname, :self, or :server. nickname should never be
# set to the client's nickname, as it's not immediately clear (within Event's context) whether 
# the nickname belongs to this client or not.
# event.where should be set to the channel or :self if directed to the current nick, for the same reason

module IRC
  
  # Event is an abstract IRC event. This is used by the StateManager plugin to keep a log
  # of events for use by external clients (e.g. Rails app).
  class Event
    attr_reader :id, :time
    attr_accessor :who, :where, :what, :context
    alias :data :what # sometimes this makes more sense (semantically)
    
    def initialize(opts = {})
      @id, @time = Event.new_instance_info
      @who, @where, @what, @context = opts[:who], opts[:where], opts[:what], opts[:context]
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
    
  # channel-related:
  class JoinEvent < Event; end # joining a channel
  class PartEvent < Event; end # leaving a channel
  class QuitEvent < Event; end # quitting the server
  class TopicEvent < Event; end # topic change in a channel, or when joining
  class NickChangeEvent < Event; end # self nick change
  class NameListEvent < Event; end # server is listing names in a chan
  class EndOfNamesEvent < Event; end # server is done listing names in a chan

  # message-related:
  class PrivMsgEvent < Event; end # private message, either to a chan or to a person
  class NoticeEvent < Event; end # notice event, either to a chan or to a person
  
  # etc.
  class UnknownServerEvent < Event; end # catchall for unknown server messages
  
end
