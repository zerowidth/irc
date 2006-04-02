require 'irc/plugin'

module IRC

class CorePlugin < IRC::Plugin
  
  register_for RPL_WELCOME, CMD_NICK, ERR_NICKNAMEINUSE, ERR_ERRONEUSNICKNAME
  
  # RPL_WELCOME, sent when registration with network was successful
  # get the nickname from the config and set it in the state
  def m001(message)
    @state[:nick] = @state[:newnick].shift
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
  
  def nick(message)
    if message.prefix[:nick] == @state[:nick] && message.params[0] == @state[:newnick].first
        @state[:nick] = @state[:newnick].shift
    end
  end
  
  def m433(message) # ERR_NICKNAMEINUSE
    @state[:newnick].shift # assumed that nick commands are handled in order
    unless @state[:nick] # nick isn't set during registration, so try a new nick
      @command_queue.add(NickCommand.new(message.params[1]+'_'))
    end
  end
  
  def m432(message) # ERR_ERRONEUSNICKNAME
    @state[:newnick].shift # assumed that nick commands are handled in order
    
    # if the client hasn't registered yet, there's no easy way to recover.
    raise 'Invalid nick specified, could not register with server' unless @state[:nick]
  end
  
end

end # module