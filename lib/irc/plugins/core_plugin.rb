require 'irc/plugin'

module IRC

class CorePlugin < IRC::Plugin
  
  def registered_with_server
    @client.state[:nick] = @client.state[:newnick].shift
  end

  # nick handling, both changes and errors.
  # Possible contexts:
  # - before RPL_WELCOME (during registration)
  # - after registration (normal operation)
  # Events:
  # - welcome: last attempted nick change (includes the initial try) was successful
  # - nick:
  #   - for previous nick change attempt (remove from queue, set nick)
  #   - for last nick change attempt (handle the same way?)
  #   - for someone else (not handled here)
  # - error:
  #   - nick in use, nick invalid, etc.: if pre-registration, try something else. otherwise,
  #     drop the attempted nick from the list.
  
  def nick_change(who, what)
    if who = @client.state[:nick] && @client.state[:newnick] && what == @client.state[:newnick].first
      @client.state[:nick] = @client.state[:newnick].shift
    end
  end
  
  def nick_in_use # ERR_NICKNAMEINUSE, nickname is already in use
   tried = @client.state[:newnick].shift # assumed that nick commands are handled in order!
   unless @client.state[:nick] # nick isn't set during registration, so try a new nick
     @client.change_nick tried + '_'
   end
  end
    
  def nick_invalid # ERR_ERRONEUSNICKNAME
    @client.state[:newnick].shift # assumed that nick commands are handled in order
    # if the client hasn't registered yet, there's no easy way to recover.
    raise 'Invalid nick specified, could not register with server' unless @client.state[:nick]
  end
  
  # ping/pong (server keepalive)
  def server_ping(param)
    @client.send_raw CMD_PONG + ' ' + param
  end
    
end

end # module