module IrcHelper
  def irc_timestamp(time)
    time.strftime '[%H:%M:%S]'
  end  
end
