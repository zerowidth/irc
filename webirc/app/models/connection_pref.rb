class ConnectionPref < ActiveRecord::Base
  
  belongs_to :user

  validates_presence_of :nick, :realname, :server, :port, :user_id
  validates_length_of :nick, :within => 1..40
  validates_length_of :realname, :within => 1..40
  validates_length_of :server, :within => 1..40
  #validates_length_of :channel, :within => 1..80
  
  def self.new_with_defaults(attrs)
    defaults = {
      :nick     => DEFAULT_NICKNAME,
      :realname => DEFAULT_REALNAME,
      :server   => DEFAULT_SERVER,
      :port     => DEFAULT_PORT
    }
    defaults[:channel] = DEFAULT_CHANNEL if self.const_defined? :DEFAULT_CHANNEL
    ConnectionPref.new defaults.merge(attrs)
  end
  
  def to_hash
    { :nick => nick, 
      :realname => realname, 
      :server => server, 
      :port => port, 
      :channel => channel
    }
  end
  
end
