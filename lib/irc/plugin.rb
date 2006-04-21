=begin
basic Plugin class
All program plugins should inherit from this class.

When subclassing, define the methods for whatever commands/replies the plugin is handling
as defined in rfc2812.rb
Numeric reply methods are prefixed with 'm':
  def privmsg(message) handles CMD_PRIVMSG 
  def m001(message) handles RPL_WELCOME

A plugin is automatically registered with the plugin handler when it inherits from Plugin.
You can register a plugin explicitly using PluginManager.register_plugin YourPluginClass

=end
# so plugins can merely require 'irc/plugin' and have access to PluginManager
require 'irc/plugin_manager' 
require 'irc/client_commands' # for creating new commands 
require 'irc/message' # messages to handle

module IRC

class Plugin
  
  cattr_accessor :logger
  
  def initialize(command_queue, config, state)
    @command_queue = command_queue
    @config = config
    @state = state
  end
  
  # redefine this to perform any cleanup work
  # this is called before a plugin manager instance shuts down
  def teardown
  end
    
  private #############################
  # helper methods:

  def reply(who, text)
    send_command(CMD_PRIVMSG, "#{who} :#{text}")
  end
  
  # TODO: reply_in_private for private replies to public messages
  
  def reply_action(who, text)
    send_command(CMD_PRIVMSG, "#{who} :\001ACTION #{text}\001")
  end


  def send_command(command,param_string)
    @command_queue << SendCommand.new("#{command} #{param_string}")
  end
  
  # query helpers, use these to ask simple questions about messages  
  def destination_of(msg)
    if directed_message?(msg)
      private_message?(msg) ? @state[:nick] : msg.params[0]
    else
      @state[:nick]
    end
  end

  # a message is considered private if it's directed to this particular client
  # via a directed message (privmsg, notice)
  def private_message?(msg)
    directed_message?(msg) && msg.params && 
      ( @state[:nick] && msg.params[0].downcase == @state[:nick].downcase )
  end
  
  # a directed message means it's a message specifically targeted to a nick or channel
  # (that is, a privmsg or a notice)
  def directed_message?(msg)
    msg.message_type == CMD_PRIVMSG || msg.message_type == CMD_NOTICE
  end
  
  # auto-register any plugin that inherits from Plugin
  def self.inherited(child_class)
    PluginManager.register_plugin(child_class)
  end
  
end
  
end