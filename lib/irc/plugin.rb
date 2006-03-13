=begin
basic Plugin class
All program plugins should inherit from this class.

When subclassing, define the methods for whatever commands/replies the plugin is handling
as defined in rfc2812.rb
Numeric reply methods are prefixed with 'm':
  def privmsg(message) handles CMD_PRIVMSG 
  def m001(message) handles RPL_WELCOME

Also in Plugin, various helpers are defined: reply, reply_command, etc. to reply to a message.

=end
require 'irc/client_commands'
require 'irc/message'

module IRC
  
class Plugin
  
  def initialize(command_queue, config, state)
    @command_queue = command_queue
    @config = config
    @state = state
  end
  
  # redefine this to perform any cleanup work
  def teardown
  end
  
  private #############################
  # helper methods:

  def reply(msg,text)
    who = private_message?(msg) ? msg.sender : msg.params[0]
    reply_command(msg,CMD_PRIVMSG, "#{who} :#{text}")
  end

  def reply_command(msg,command,param_string)
    @command_queue.add( SendCommand.new("#{command} #{param_string}") )
  end

  def private_message?(msg)
    # check oldnick to be sure the nick isn't being changed at the moment
    directed_message?(msg) && msg.params && 
      ( @state[:nick] && msg.params[0].downcase == @state[:nick].downcase )
  end
  
  # messages can only be considered "private" if they're directed to someone
  # and match a particular type of message
  def directed_message?(msg)
    msg.message_type == CMD_PRIVMSG || msg.message_type == CMD_NOTICE
  end
  
end
  
end