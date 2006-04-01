=begin IRCCommand: commands used by the client

This generally implements the Command pattern.

Commands can be set to the following types:
  :uses_client  # for commands that need to execute or modify high-level things in the client
  :uses_socket  # for commands that need to send data
  :uses_plugins # for data commands, which talk to the plugin handler
  :uses_queue   # for commands that merely add other commands to the queue

To define a command type, include the statement
  type :sometype
in the command class definition.

For common, basic text commands that add a single send message to the command
queue (such as NICK, JOIN, PART) there is a queue_command "macro" that makes it easier:
  class NoticeCommand < IRCCommand
    queue_command CMD_NOTICE
  end

IRCCommands rely on someone else to provide the necessary and correct
arguments to their execute methods: this is assisted by the #type method.

=end

require 'irc/rfc2812'

module IRC  

# abstract definition of an IRC command
class IRCCommand
  
  # Reimplement this method, this will get called when a command is processed
  # Depending on type, the args will be different things - see comments above 
  # for how types should be defined.
  # This raises an exception because if a command's execute isn't defined then
  # it's an exceptional situation. This is a little more explicit than if the
  # method weren't defined.
  def execute(*args); 
    raise "Command #{self.inspect} execution not defined"
  end

  # this should be reimplemented by the "type :foo" macro, so this is indeed an
  # exceptional situation
  def type
    raise "Command #{self.inspect} type not initialized!"
  end
end

# Metaprogramming for "type :foo" and queue_command CMD_WHATEV
class << IRCCommand
  def type(type)
    # redefine #type to return the type (as a symbol)
    class_eval %{ def type; :#{type}; end }
  end
  
  def queue_command(command_type)
    class_eval %{
      type :uses_queue
      def initialize(data)
        @data = data
      end
      def execute(queue)
        queue.add SendCommand.new("#{command_type} " + @data)
      end
    }
  end
end

end # module
