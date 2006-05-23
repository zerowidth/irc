# StateManager plugin
#
# StateManager maintains state and an event queue for use by an IRC client front-end
# (e.g. Rails app). 
# 
# The following state is maintained:
#
#   - @state[:topics] => { 'channel' => 'topic', ... }
#   - @state[:names] => { 'channel' => [ 'nick1', 'nick2', ... ], ... }
#   - @state[:events] => [ list of events ... ]
#   
#   'channel' can be both #channels or nick queries.
# 
# I chose to place everything at a high level (directly in @state) rather than
# in @state[:channels] => { 'channel' => { :topic => ... :names => ... }} in order
# to reduce indirection:
#   @state[:topics]['chan']
# vs.
#   @state[:channels]['chan'][:topic]
# and also to allow "global" events which would otherwise lack context
#
# :events contains a list of events. This list can only reach a certain size before being 
# rolled over. The idea is that individual events have unique (incrementing) ids
# (handled by Event.new) so that other code can query the event list for events since
# the last one seen, while still maintaining a smaller memory footprint by not logging
# every event into memory permanently.
# Please note: this is *not* strictly enforced. It's only enforced within this plugin
# (for now?) and any other plugin or client can add events to the queue without
# consequence. Whenever an event gets added within this plugin, however, the event queue
# will get pruned back down to size.
#

require 'irc/plugin'
require 'irc/event'
include IRC
class StateManagerPlugin < Plugin

# TODO: add a general queue for part/quit messages to inform the client what happens 
  def initialize(queue,config,state)
    super(queue,config,state)
    state[:names] ||= {}
    state[:topics] ||= {}
    state[:events] ||= [] # single events list
    
    config[:max_event_queue_size] ||= 10000 # set this to a default if necessary
  end

  def m001(msg) # RPL_WELCOME, autorejoin if necessary
    @state[:topics].each do |chan, topic|
      @command_queue << JoinCommand.new(chan)
    end
  end
  
  def nick(msg)
    @state[:names].each_pair do |chan, namelist|
      if idx = namelist.index( msg.prefix[:nick] )
        namelist[idx] = msg.params[0]
        add_event NickChangeEvent.new \
          :who => msg.prefix[:nick], :where => chan, :what => msg.params[0], :context => self_or_nil(msg.prefix[:nick])
#          self_or_nick(msg.prefix[:nick]), chan, msg.params[0] )
      end
    end
    # TODO: privmsg/query handling
#    if @state[:names][msg.prefix[:nick]]
#      @state[:names][msg.params[0]] = @state[:names][msg.prefix[:nick]]
#      @state[:names].delete(msg.prefix[:nick])
#      add_event ...
#   end
  end
  
  def join(msg)
    if msg.prefix[:nick] == @state[:nick] # if we're the ones joining
      @state[:names][msg.params[0]] = []
      @state[:topics][msg.params[0]] = ""
    else # someone else is joining
      @state[:names][msg.params[0]] << msg.prefix[:nick]
      add_event JoinEvent.new( :who => msg.prefix[:nick], :where => msg.params[0], 
        :what => "#{msg.prefix[:user]}@#{msg.prefix[:host]}" )
    end
  end
  
  def part(msg)
    if msg.prefix[:nick] == @state[:nick]
      @state[:names].delete(msg.params[0])
      @state[:topics].delete(msg.params[0])
    else
      @state[:names][msg.params[0]].delete(msg.prefix[:nick])
    end
    add_event PartEvent.new( :who => msg.prefix[:nick], :where => msg.params[0],
      :what => ["#{msg.prefix[:user]}@#{msg.prefix[:host]}", msg.params[1] ], :context => self_or_nil(msg.prefix[:nick]) )
  end
  
  def quit(msg)
    # assumed that it's someone else, since a self quit will close everything down
    # including state
    @state[:names].each_pair do |chan,namelist|
      if idx = namelist.index(msg.prefix[:nick])
        namelist.delete_at(idx)
        add_event QuitEvent.new( :who => msg.prefix[:nick], :where => chan, 
          :what => ["#{msg.prefix[:user]}@#{msg.prefix[:host]}", msg.params[0] ] )
      end
    end
  end
  
  def topic(msg)
    topic_change msg.prefix[:nick], msg.params[0], msg.params[1]
  end
  
  def m332(msg) # RPL_TOPIC
    topic_change nil, msg.params[1], msg.params[2]
  end
  
  def m353(msg) # RPL_NAMREPLY # update the name lists
    # TODO: handle opers in channels (@nick) properly
    # ignore ops for now.
    @state[:names][msg.params[2]] |= msg.params[3].split(/\s/).map! {|nick| nick.gsub('@','')} 
    add_event NameListEvent.new( :who => msg.prefix[:server], :where => msg.params[2], 
      :what => msg.params[3], :context => :server )
  end
  
  def m366(msg) # RPL_ENDOFNAMES # inform the client that the names have been updated
    # event to inform the client that the names are finished updating
    add_event EndOfNamesEvent.new( :who => msg.prefix[:server], :where => msg.params[1],
      :what => msg.params[2], :context => :server )
  end
  
  ##### messaging
  
  def privmsg(msg)
    where = destination_of(msg)
    add_event PrivMsgEvent.new( :who => msg.prefix[:nick], :where => where, :what => msg.params[1],
      :context => self_or_nil(where) )
  end
  
  def notice(msg)
    who = msg.prefix[:nick] || msg.prefix[:server]
    where = destination_of(msg)
    context = self_or_nil(where)
    context = :server if msg.prefix[:server]
    add_event NoticeEvent.new( :who => who, :where => where, :what => msg.params[1], 
      :context => context )
  end
  
  ##### catchall
  def catchall(msg)
    context = self_or_server(msg)
    add_event UnknownServerEvent.new(:who => msg.prefix[:nick] || msg.prefix[:server], 
      :where => destination_of(msg), :what => msg.params, :context => self_or_server(msg) )
  end
  
  ##### helpers
  
  def self_or_nil(nick)
    nick == @state[:nick] ? :self : nil
  end
  
  def self_or_server(msg)
    return self_or_nil(msg.prefix[:nick]) if msg.prefix[:nick]
    return :server if msg.prefix[:server]
  end
  
  def add_event(event)
    # TODO: replace this with a LimitedSizeArray class? probably not that critical
    # as long as events is generally kept down to size.
    @state[:events] << event
    # keep the list of events pared down
    while @state[:events].size > @config[:max_event_queue_size] do @state[:events].shift end
  end
  
  # DRY code:
  
  def topic_change(who, where, topic)
    @state[:topics][where] = topic
    add_event TopicEvent.new(:who => who, :where => where, :what => topic)
  end

end