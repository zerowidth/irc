module IRC
  
  class Message
    
    ##### incoming messages

    # returns [{prefix hash}, message_type, [params array]]
    def Message.parse_message(data)
      data.strip!
      prefix = message_type = params = nil
      if data =~ Patterns::MESSAGE
        prefix, message_type, params = $~.captures         
      else
        puts "warning: could not parse message #{data}"
      end
      
      # clear whitespace
      #prefix.strip! if prefix
      #params.strip! if params

      prefix = parse_prefix(prefix)
      params = parse_params(message_type,params)

      [prefix,message_type,params]
    end
    
    private
    
    # parses the prefix, returns hash of {:hostname, :nick, :user, :host}
    def Message.parse_prefix(prefix)
      return {} unless prefix # edge case
      if prefix =~ Patterns::PREFIX
        hostname, nick, user, host = $~.captures 
        {:hostname => hostname, :nick => nick, :user => user, :host => host}
      else
        {}
      end
    end
    
    # returns an array of values based on the message type received
    # default hash is [target, message]
    def Message.parse_params(message_type,params)
      case message_type
      # commands not handled by default
      when CMD_PING, CMD_ERROR
        parse_args( 1, params )
      # server replies
      when RPL_AWAY, RPL_WHOISOPERATOR, RPL_ENDOFWHOIS, RPL_WHOISCHANNELS, RPL_ENDOFWHOWAS,
        RPL_UNIQOPIS, RPL_NOTOPIC, RPL_TOPIC, RPL_INVITING, RPL_SUMMONING, RPL_INVITELIST, RPL_ENDOFINVITELIST,
        RPL_EXCEPTLIST, RPL_ENDOFEXCEPTLIST, RPL_ENDOFWHO, RPL_NAMREPLY, RPL_ENDOFNAMES, RPL_ENDOFLINKS,
        RPL_BANLIST, RPL_ENDOFBANLIST, RPL_REHASHING, RPL_TIME, RPL_ENDOFSTATS, RPL_STATSOLINE, RPL_LUSEROP,
        RPL_LUSERUNKNOWN, RPL_LUSERCHANNELS, RPL_ADMINME, RPL_TRYAGAIN
        parse_args( 3, params )
      when RPL_WHOISSERVER, RPL_WHOWASUSER, RPL_LIST, RPL_CHANNELMODEIS, RPL_VERSION,
        RPL_LINKS, RPL_TRACECONNECTING, RPL_TRACEHANDSHAKE, RPL_TRACEUNKNOWN, RPL_TRACEOPERATOR, 
        RPL_TRACEUSER, RPL_TRACENEWTYPE, RPL_TRACECLASS, RPL_TRACELOG, RPL_TRACEEND, RPL_SERVLISTEND
        parse_args( 4, params )
      when RPL_WHOISUSER, RPL_WHOISIDLE, RPL_STATSCOMMANDS
        parse_args( 5, params )
      when RPL_TRACESERVICE
        parse_args( 6, params )
      when RPL_WHOREPLY, RPL_SERVLIST
        parse_args( 7, params )
      when RPL_TRACESERVER, RPL_STATSLINKINFO
        parse_args( 8, params )
      when RPL_TRACELINK
        parse_args( 9, params )
      # server errors
      when ERR_YOUWILLBEBANNED
        parse_args( 1, params )
      when ERR_NOSUCHNICK, ERR_NOSUCHSERVER, ERR_NOSUCHCHANNEL, ERR_CANNOTSENDTOCHAN, ERR_TOOMANYCHANNELS,
        ERR_WASNOSUCHNICK, ERR_TOOMANYTARGETS, ERR_NOSUCHSERVICE, ERR_WILDTOPLEVEL, ERR_BADMASK, 
        ERR_UNKNOWNCOMMAND, ERR_NOADMININFO, ERR_ERRONEUSNICKNAME, ERR_NICKNAMEINUSE, ERR_NICKCOLLISION,
        ERR_UNAVAILRESOURCE, ERR_NOTONCHANNEL, ERR_NOLOGIN, ERR_NEEDMOREPARAMS,
        ERR_KEYSET, ERR_CHANNELISFULL, ERR_UNKNOWNMODE, ERR_INVITEONLYCHAN, ERR_BANNEDFROMCHAN, 
        ERR_BADCHANNELKEY, ERR_BADCHANMASK, ERR_NOCHANMODES, 
        ERR_CHANOPRIVSNEEDED
        parse_args( 3, params )
      when ERR_USERNOTINCHANNEL, ERR_USERONCHANNEL, ERR_BANLISTFULL
        parse_args( 4, params )
      else # nearly everything takes two args, <dest> :message
        parse_args( 2, params )
      end
    end
    
    def Message.parse_args(num_args,params)
      postfix = ':?(.*)?$' # optional last arg, gets set to nil if not found
      prefix = '^\s*'
      arg = '(\S+)\s*'
      final = prefix
      (num_args-1).times do 
        final += arg
      end
      final += postfix
      r = Regexp.new(final) # TODO: see if caching this makes it faster
      if params =~ r
        $~.captures
      else
        puts "warning: could not parse params for this message"
        [params]
      end
    end
    
  end
  
end