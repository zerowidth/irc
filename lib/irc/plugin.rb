=begin
basic Plugin class
All Client plugins should inherit from this class.

When subclassing, define the methods for whatever callbacks the plugin is handling
as defined in rfc2812.rb
Numeric reply methods are prefixed with 'm':
  def privmsg(message) handles CMD_PRIVMSG 
  def m001(message) handles RPL_WELCOME

TODO clean this documentation up

A plugin is automatically registered with the plugin handler when it inherits from Plugin.
You can register a plugin explicitly using PluginManager.register_plugin YourPluginClass, but 
you shouldn't need to ever do this.

=end

require 'irc/plugin_manager' 

module IRC

class Plugin
  
  cattr_accessor :logger
  
  def initialize(client)
    @client = client
  end
  
  # redefine this to perform any cleanup work
  # this callback is invoked prior to the client shutting down
  def teardown
  end
    
  # private #############################
  # # helper methods:
  # 
  # def reply(who, text)
  #   send_command(CMD_PRIVMSG, "#{who} :#{text}")
  # end
  #   
  # # TODO: reply_in_private for private replies to public messages
  #   
  # def reply_action(who, text)
  #   send_command(CMD_PRIVMSG, "#{who} :\001ACTION #{text}\001")
  # end
  # 
  # 
  # def send_command(command,param_string)
  #   @command_queue << SendCommand.new("#{command} #{param_string}")
  # end
  #   
  # # query helpers, use these to ask simple questions about messages  
  # def destination_of(msg)
  #   if directed_message?(msg)
  #     private_message?(msg) ? @state[:nick] : msg.params[0]
  #   else
  #     @state[:nick]
  #   end
  # end
  # 
  # # a message is considered private if it's directed to this particular client
  # # via a directed message (privmsg, notice)
  # def private_message?(msg)
  #   directed_message?(msg) && msg.params && 
  #     ( @state[:nick] && msg.params[0].downcase == @state[:nick].downcase )
  # end
  #   
  # # a directed message means it's a message specifically targeted to a nick or channel
  # # (that is, a privmsg or a notice)
  # def directed_message?(msg)
  #   msg.message_type == CMD_PRIVMSG || msg.message_type == CMD_NOTICE
  # end
  #   
  # auto-register any plugin that inherits from Plugin
  def self.inherited(child_class)
    PluginManager.register_plugin(child_class)
  end
  
end
  
end