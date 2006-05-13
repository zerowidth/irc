# Connection represents the data required to establish a connection with an irc server.
class Connection
  include Validateable # rails recipe #64
  
  attr_accessor :nick, :realname, :server, :port, :channel

  validates_presence_of :nick, :realname, :server, :port
  
  def initialize(opts = {})
    self.nick = opts[:nick]
    self.realname = opts[:realname]
    self.server = opts[:server]
    self.port = opts[:port]
    self.channel = opts[:channel]
  end

end
