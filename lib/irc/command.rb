=begin IRCCommand: commands used by the client

This generally implements the Command pattern.

Commands can be subclassed from the following classes:
  ClientCommand # for commands that need to execute or modify high-level things in the client
  SocketCommand # for commands that need to send data
  PluginCommand # for data commands, which talk to the plugin handler
  QueueCommand  # for commands that merely add other commands to the queue

For common, basic text commands that add a single send message to the command
queue (such as NICK, JOIN, PART) there is a simple_queue_command "macro" that makes it easier:
  class NoticeCommand < QueueCommand
    simple_queue_command CMD_NOTICE
  end

IRCCommands rely on someone else (IRC::Client) to provide the necessary and correct
arguments to their execute methods: this is assisted by subclassing the correct command class

=end

require 'irc/rfc2812'

module IRC  

# abstract definition of an IRC command
# #execute must be defined in subclasses. This will be called when a command is handled
# by Client. The arguments to execute will vary depending on what type of command it is.
class IRCCommand; end

# basic subtypes
# subtype execute commands invoke IRCCommand#execute, which raises an exception.
class ClientCommand < IRCCommand; end # execute is called with a Client
class SocketCommand < IRCCommand; end # execute is called with an IRCConnection
class PluginCommand < IRCCommand; end # execute is called with a PluginManager
class QueueCommand < IRCCommand; end # execute is called with a CommandQueue
class QueueConfigStateCommand < IRCCommand; end # called with queue, config, and state

# Metaprogramming for simple_queue_command CMD_WHATEV.
# invoked within a QueueCommand subclass definition, this will define the basic methods
# required to handle a simple queue command. 
class << QueueCommand
  def simple_queue_command(command_type)
    class_eval %{
      def initialize(data)
        @data = data
      end
      def execute(command_queue)
        command_queue.add SendCommand.new("#{command_type} " + @data)
      end
    }
  end
end

end # module
