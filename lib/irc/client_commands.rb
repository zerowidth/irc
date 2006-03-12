require 'irc/command'
require 'irc/message'

module IRC

class DataCommand < IRCCommand
  type :uses_plugins

  def initialize(data)
    @data = data
  end
  
  def execute(plugin_handler)
    msg = Message.new(@data)
  end

end
  
end # module