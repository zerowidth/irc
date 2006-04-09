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
#
# :events contains a list of events. This list can only reach a certain size before being 
# rolled over. The idea is that individual events have unique (incrementing) ids
# (handled by Event.new) so that other code can query the event list for events since
# the last one seen, while still maintaining a smaller memory footprint by not logging
# every event into memory permanently.
#

require 'irc/plugin'
require 'irc/event'
include IRC
class StateManagerPlugin < Plugin
  
  MAX_EVENT_QUEUE_SIZE = 3000 # max size of event queue (stored in state for a chan)
  
  # basic state management - if these happen, keep the state
  register_for CMD_NICK, CMD_JOIN, CMD_PART, CMD_QUIT, CMD_TOPIC
  register_for RPL_TOPIC, RPL_NAMREPLY, RPL_ENDOFNAMES, RPL_WELCOME
 
# TODO: add a general queue for part/quit messages to inform the client what happens 
  def initialize(queue,config,state)
    super(queue,config,state)
    state[:names] ||= {}
    state[:topics] ||= {}
    state[:events] ||= [] # single events list
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
        add_event NickChangeEvent.new(
          self_or_nick(msg.prefix[:nick]), chan, msg.params[0] )
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
      add_event JoinEvent.new(msg.prefix[:nick], msg.params[0], 
        "#{msg.prefix[:user]}@#{msg.prefix[:host]}" )
    end
  end
  
  def part(msg)
    if msg.prefix[:nick] == @state[:nick]
      @state[:names].delete(msg.params[0])
      @state[:topics].delete(msg.params[0])
    else
      @state[:names][msg.params[0]].delete(msg.prefix[:nick])
    end
    add_event PartEvent.new( self_or_nick(msg.prefix[:nick]), msg.params[0],
      ["#{msg.prefix[:user]}@#{msg.prefix[:host]}", msg.params[1] ]   )
  end
  
  def quit(msg)
    # assumed that it's someone else, since a self quit will close everything down
    # including state
    @state[:names].each_pair do |chan,namelist|
      if idx = namelist.index(msg.prefix[:nick])
        namelist.delete_at(idx)
        add_event QuitEvent.new(msg.prefix[:nick], chan, 
          ["#{msg.prefix[:user]}@#{msg.prefix[:host]}", msg.params[0] ] )
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
    add_event NameListEvent.new(msg.params[0], msg.params[2], msg.params[3])
  end
  
  def m366(msg) # RPL_ENDOFNAMES # inform the client that the names have been updated
    # event to inform the client that the names are finished updating
    add_event EndOfNamesEvent.new(nil, msg.params[1], msg.params[2])
  end
  
  ##### helpers
  
  def self_or_nick(nick)
    nick == @state[:nick] ? :self : nick
  end
  
  def add_event(event)
    @state[:events] << event
    # keep the list of events pared down
    while @state[:events].size > MAX_EVENT_QUEUE_SIZE do @state[:events].shift end
  end
  
  def topic_change(who, where, topic)
    @state[:topics][where] = topic
    add_event TopicEvent.new(who, where, topic)
  end

end