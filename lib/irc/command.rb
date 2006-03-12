# Commands used by the client
# This generally implements the Command pattern
# Commands can be set to the following types:
#   :uses_client  # for commands that need to execute or modify high-level things in the client
#   :uses_socket  # for commands that need to send data
#   :uses_plugins # for data commands, which talk to the plugin handler
#   :uses_queue   # for commands that merely add other commands to the queue
# To define a command type, include the statement
#   type :sometype
# in the command class definition

module IRC  

# abstract definition of an IRC command
class IRCCommand
  
  # Reimplement this method, this will get called when a command is processed
  # Depending on type, the args will be different things - see comments above 
  # for how types should be defined.
  # TODO: better to just leave this undefined and let the parser handle it? PERHAPS!
  def execute(*args); 
    raise "Command #{self.inspect} execution not defined"
  end

  # this should be reimplemented by the "type :foo" macro, so this is indeed an
  # exceptional situation
  def type
    raise "Command #{self.inspect} type not initialized!"
  end
end

# Metaprogramming for "type :foo" macro
class << IRCCommand
  def type(type)
    # redefine #type() to return the type (as a symbol)
    class_eval %{ def type; :#{type}; end }
  end
end

end # module