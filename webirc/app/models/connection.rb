class Connection
  include Validateable # rails recipe #64
  
  attr_accessor :nick, :realname, :server, :port, :channel

  validates_presence_of :nick, :realname, :server, :port, :channel
  
  def initialize(opts = {})
    self.nick = opts[:nick]
    self.realname = opts[:realname]
    self.server = opts[:server]
    self.port = opts[:port]
    self.channel = opts[:channel]
  end
  
  p DEFAULT_NICKNAME

end
