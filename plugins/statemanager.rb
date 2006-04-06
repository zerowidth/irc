# StateManager plugin
#
# StateManager maintains state and an event queue for use by an IRC client front-end
# (e.g. Rails app). 
# 
# The following state is maintained:
#
#   - @state[:topics] => { 'channel' => 'topic', ... }
#   - @state[:names] => { 'channel' => [ 'nick1', 'nick2', ... ], ... }
#   - @state[:events] => { 'channel' => [ event1, event2, ... ] }
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
# :events contains arrays of events. These can only reach a certain size before being 
# rolled over. The idea is that individual events have unique (incrementing) ids
# (handled by EventFactory) so that other code can query the event lists for events since
# the last one seen, while still maintaining a smaller memory footprint by not logging
# every event into memory permanently.
#

require 'irc/plugin'
require 'irc/event'
include IRC
class StateManagerPlugin < Plugin
  
  MAX_EVENT_QUEUE_SIZE = 3000 # max size of event queue (stored in state)
  
  register_for CMD_NICK, CMD_JOIN, CMD_PART, CMD_QUIT
  register_for RPL_TOPIC, RPL_NAMREPLY, RPL_ENDOFNAMES
 
# TODO: add a general queue for part/quit messages to inform the client what happens 
#  def initialize(queue,config,state)
#    super(queue,config,state)
#    state.merge! { :names=>{}, :topics=>{}, :events=>{:general=>[]} }
#  end
  
  def nick(msg)
    @state[:names].each_pair do |chan, namelist|
      if idx = namelist.index( msg.prefix[:nick] )
        namelist[idx] = msg.params[0]
        add_event(chan, EventFactory.new_event(
          :nickchange, :update, chan, msg.prefix[:nick], msg.params[0], nil) )
      end
    end
    # TODO: privmsg/query handling
#    if @state[:names][msg.prefix[:nick]]
#      @state[:names][msg.params[0]] = @state[:names][msg.prefix[:nick]]
#      @state[:names].delete(msg.prefix[:nick])
#      add_event...
#   end
  end
  
  def join(msg)
    if msg.prefix[:nick] == @state[:nick] # if we're the ones joining
      @state[:names][msg.params[0]] = []
      @state[:topics][msg.params[0]] = ""
      @state[:events][msg.params[0]] = []
    else # someone else is joining
      @state[:names][msg.params[0]] << msg.prefix[:nick]
      add_event(msg.params[0], EventFactory.new_event(
        :join, :update, msg.params[0], msg.prefix[:nick], nil, 
        "#{msg.prefix[:user]}@#{msg.prefix[:host]}") )
    end
  end
  
  def part(msg)
    if msg.prefix[:nick] == @state[:nick]
      @state[:names].delete(msg.params[0])
      @state[:topics].delete(msg.params[0])
      @state[:events].delete(msg.params[0])
      # could potentially add an event to a general queue with an event saying 'i left this chan'
    else
      @state[:names][msg.params[0]].delete(msg.prefix[:nick])
      add_event(msg.params[0], EventFactory.new_event(
        :part, :server, msg.params[0], msg.prefix[:nick], 
        "#{msg.prefix[:user]}@#{msg.prefix[:host]}", msg.params[1] ) )
      add_event(msg.params[0], EventFactory.new_event(
        :part, :update, msg.params[0], msg.prefix[:nick], 
        "#{msg.prefix[:user]}@#{msg.prefix[:host]}", msg.params[1] ) )
    end
  end
  
  def quit(msg)
    # assume it's someone else!
    @state[:names].each_pair do |chan,namelist|
      if idx = namelist.index(msg.prefix[:nick])
        namelist.delete_at(idx)
        add_event(chan, EventFactory.new_event(
          :quit, :server, chan, msg.prefix[:nick], 
          "#{msg.prefix[:user]}@#{msg.prefix[:host]}", msg.params[0] ) )
        add_event(chan, EventFactory.new_event(
          :quit, :update, chan, msg.prefix[:nick], 
          "#{msg.prefix[:user]}@#{msg.prefix[:host]}", msg.params[0] ) )
      end
    end
  end
  
  def m332(msg) # RPL_TOPIC
    @state[:topics][msg.params[1]] = msg.params[2]
    add_event(msg.params[1], EventFactory.new_event(
      :topic, :update, msg.params[1], nil, nil, msg.params[2]) )
  end
  
  def m353(msg) # RPL_NAMREPLY # update the name lists
    # TODO: handle opers in channels (@nick) properly
    # ignore ops for now.
    @state[:names][msg.params[2]] |= msg.params[3].split(/\s/).map! {|nick| nick.gsub('@','')} 
    add_event(msg.params[2], EventFactory.new_event(
      :names, :server, msg.params[2], nil, msg.params[0], msg.params[3]) )
  end
  
  def m366(msg) # RPL_ENDOFNAMES # inform the client that the names have been updated
    # event to inform the client that the names are finished updating
    add_event(msg.params[1], EventFactory.new_event(
      :end_of_names, :update, msg.params[1], nil, msg.params[0], msg.params[2] ) )
  end
  
  ##### helpers
  
  def add_event(where, event)
    @state[:events][where] ||= []
    @state[:events][where] << event
    while @state[:events][where].size > MAX_EVENT_QUEUE_SIZE do @state[:events][where].shift end
  end

end