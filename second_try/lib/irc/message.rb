require 'irc/rfc2812'

module IRC
  class Message
    include IRC # for command consts
    attr_reader :client # irc client that sent this message, use for replies &c

    # message parts
    attr_reader :prefix # hash of :nick, :user, :host, :server
    attr_reader :params # broken up into an array based on the command
    attr_reader :sender # who sent the message
    attr_reader :receiver # who the message was addressed to
    attr_reader :message_type # CMD_*, RPL_*, etc.
    
    attr_reader :raw_message # raw message text, useful for debugging or advanced parsing (heh)
    
    def initialize(client,data)
      @client = client
      @prefix = {}
      @params = []
      @sender = @receiver = @message_type = nil
      @raw_message = data
      parse_message(data)
    end

    def private?
      targeted_message? && @params && @params[0].downcase == @client.config[:nick].downcase
    end

    def reply(msg, to=nil)
      to ||= private? ? @sender: @receiver
      # this is where notify prefs would go, if they existed
      reply_command(CMD_PRIVMSG, to + ' :' + msg)
    end

    def reply_command(command, params_str)
      @client.send_raw(command + ' ' + params_str)
    end

    private # --------------------------------------------------

    def parse_message(data)

      case data
      when /^:(\S+)\s(\S+)\s(.*)$/
        prefix, type, message = $~.captures
      when /^([^:]\S+)\s(.*)$/
        type, message = $~.captures
      else
        puts "could not parse: #{data}" 
        return
      end

      # parse the prefix. if it doesn't fall into these two categories, then
      # leave the prefix empty (this can happen!)
      if prefix =~ /^[^@]+$/ # just the server
        @prefix[:server] = prefix
      elsif prefix =~ /^(\S+)!(\S+)@(\S+)$/
        @prefix[:nick], @prefix[:user], @prefix[:host] = $~.captures        
      end
      
      # that first bit of code acts as a basic (basic!) "correctness" test
      # now, go ahead and set the rest of the stuff
      
      # split up the message around the :
      params, message = message.split(':',2)
      params = params.split(/\s+/)
      @params << params << message
      @params.flatten! # params is an array, so flatten it after it's added
      
      @sender = @prefix[:server] ? @prefix[:server] : @prefix[:nick]
      @receiver = private? ? @receiver = @client.config[:nick] : @params[0]

      @message_type = type
      
    end
    
    def targeted_message? 
      # add more to this? perhaps! but not now! for now it's just these two!
      @message_type == CMD_PRIVMSG || @message_type == CMD_NOTICE
    end

  end
end
