# event types:
# type          category        where   from        to        data
# -----------------------------------------------------------------------------
# :motd         :servermessage  nil                           motd string
# :nickchange   :update         chan/   old nick    new nick  none
#                               nick
# :join         :update         chan    nick        nil       ~user@host
# :names        :servermessage  chan    nil         nick      nick list
# :end_of_names :update         chan    nil         nick      end of list (server message)

module IRC
  
  # Event is an IRC event. This is used by the StateManager plugin to keep a log
  # of events for use by external clients (e.g. Rails app)
  class Event
    attr_reader :id, :time
    attr_accessor :type, :category, :where, :from, :to, :data
    
    def initialize(id, time, type, category, where, from, to, data)
      @id = id
      @time = time
      @type = type
      @category = category
      @where = where
      @from = from
      @to = to
      @data = data
    end
  end
  
  # Factory class creates a new event with a unique (incrementing) id and fresh timestamp.
  # This could theoretically be replaced with a database insert or something of the sort
  # that also returns a unique ID.
  # TODO: clean this up? perhaps change the interface to (type, category, options = {} )
  class EventFactory
    def self.new_event( type, category, where, from, to, data )
      @@id ||= 0
      @@id += 1
      Event.new( @@id, Time.now, type, category, where, from, to, data )
    end
  end
  
  
end