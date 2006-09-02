# StateManager plugin
#
# StateManager maintains state and an event queue for use by an IRC client front-end
# (e.g. Rails app).
# 
# The following state is maintained:
#
#   - @client.state[:topics] => { 'channel' => 'topic', ... }
#   - @client.state[:names] => { 'channel' => [ 'nick1', 'nick2', ... ], ... }
#   - @client.state[:events] => [ list of events ... ]
#   
#   'channel' can be both #channels or nick queries. (soon, anyway)
# 
# I chose to place everything at a high level (directly in @client.state) rather than
# in @client.state[:channels] => { 'channel' => {.., :events => ...}  } in order
# to reduce indirection:
#   @client.state[:topics]['chan']
# vs.
#   @client.state[:channels]['chan'][:topic]
# and also to allow "global" events which would otherwise lack context.
#
# :events contains a list of events. This list can only reach a certain size before being 
# rolled over. The idea is that individual events have unique (incrementing) ids
# (handled by Event.new) so that other code can query the event list for events since
# the last one seen, while still maintaining a smaller memory footprint by not logging
# every event into memory permanently.
# Please note: this is *not* strictly enforced. It's only enforced within this plugin
# and any other plugin or client can add events to the queue without consequence. 
#

require 'irc/plugin'
require 'irc/event'
include IRC
class StateManagerPlugin < Plugin

  def initialize(client)
    super(client)
    # TODO: add a general queue for part/quit messages to inform the client what happens 
    client.state[:names] ||= {}
    client.state[:topics] ||= {}
    client.state[:events] ||= [] # single events list
    
    client.config[:max_event_queue_size] ||= 10000 # set this to a default if necessary
  end
  
  # ----- connection callbacks -----
  
  def registered_with_server
    # autorejoin if necessary
    if @client.state[:topics]
      @client.state[:topics].each {|chan, topic| @client.join_channel(chan) }
      # the other info (events, topics) should either stay or will be reset later
    end
  end
  
  def disconnected
    add_event DisconnectedEvent.new(:context => :server)
  end
  
  def connection_error(err)
    add_event ConnectionErrorEvent.new(:context => :server, :what => err)
  end
  
  # ----- channel callbacks -----

  def nick_changed(from, to)
    @client.state[:names].each_pair do |chan, namelist|
      namelist.map! { |name| name = to if name == from }
      add_event NickChangedEvent.new(
        :who => from, :where => chan, :what => to, :context => self_or_nil(from) )
    end
    # TODO: privmsg/query handling when in a privmsg and the person changes their nick
    # if @client.state[:names][msg.prefix[:nick]]
    #   @client.state[:names][msg.params[0]] = @client.state[:names][msg.prefix[:nick]]
    #   @client.state[:names].delete(msg.prefix[:nick])
    #   add_event ...
    # end
  end

  def joined_channel(who, chan)
    nick, username = *who
    if nick == @client.state[:nick]
      @client.state[:names][chan] = []
      logger.info "setting topics sub #{chan}, topics is #{@client.state[:topics].inspect}"
      @client.state[:topics][chan] = ""
      add_event JoinEvent.new( :who => nick, :where => chan, :what => username, :context => :self )
    else # someone else is joining
      @client.state[:names][chan] << nick
      add_event JoinEvent.new( :who => nick, :where => chan, :what => username )
    end
      
  end
  
  def left_channel(who, chan, reason)
    nick = who.nick
    if nick == @client.state[:nick]
      @client.state[:names].delete(chan)
      @client.state[:topics].delete(chan)
      add_event PartEvent.new( :who => nick, :where => chan, :what => reason, :context => :self )
    else
      @client.state[:names][chan].delete(nick)
      add_event PartEvent.new( :who => nick, :where => chan, :what => reason )
    end
  end

  def quit_server(who, reason)
    nick, username = *who
    # assumed that it's someone else, since a self quit will close everything down
    # including state
    @client.state[:names].each_pair do |chan,namelist|
      if namelist.include?(nick)
        namelist.delete(nick)
        add_event QuitEvent.new( :who => nick, :where => chan, :what => reason )
      end
    end
  end

  def topic_changed(chan, topic, whom)
    @client.state[:topics][chan] = topic
    add_event TopicChangedEvent.new(:who => whom, :where => chan, :what => topic)
  end
  
  def channel_name_list(chan, names)
    @client.state[:names][chan] = names
    add_event NameListEvent.new(:who => nil, :where => chan, :what => names)
  end

  # ----- messaging -----
  def channel_message(chan, message, who)
    add_event ChannelMessageEvent.new(:who => who.nick, :where => chan, :what => message)
  end
  
  def private_message(to_whom, message, who)
    add_event PrivateMessageEvent.new(:who => who.nick, :where => to_whom, :what => message, :context => :self)
  end
  
  def channel_notice(chan, msg, who)
    add_event ChannelNoticeEvent.new( notice(chan, msg, who) )
  end
  
  def private_notice(to_whom, message, who)
    add_event PrivateNoticeEvent.new( notice(to_whom, message, who) )
  end

#   def catchall(msg)
#     context = self_or_server(msg)
#     add_event UnknownServerEvent.new(:who => msg.prefix[:nick] || msg.prefix[:server], 
#       :where => destination_of(msg), :what => msg.params, :context => self_or_server(msg) )
#   end
  # ----- helpers -----
  
  private

  def self_or_nil(nick)
    nick == @client.state[:nick] ? :self : nil
  end

  def add_event(event)
    # TODO: replace this with a LimitedSizeArray class? probably not that critical
    # as long as events is generally kept down to size.
    @client.state[:events] << event
    # keep the list of events pared down
    while @client.state[:events].size > @client.config[:max_event_queue_size] do @client.state[:events].shift end
  end

  ### keep things a little DRYer
  def notice(where, msg, who)
    if who.is_a? MessageInfo::User
      who = who.nick 
      context = self_or_nil(where)
    else
      context = :server
    end
    { :who => who, :where => where, :what => msg, :context => context}
  end

end