module IRC
  class Message
    include IRC # for command consts
    attr_reader :client # irc client that sent this message, use for replies &c
    attr_reader :prefix # hash of :nick, :host, :server, or empty hash depending
    attr_reader :params # broken up into an array based on the command
    attr_reader :sender # who sent the message
    attr_reader :receiver # who the message was addressed to
    attr_reader :message_type # CMD_*, RPL_*, etc.
    attr_reader :raw_message # raw message text, useful for debugging or advanced parsing (heh)
    #attr_reader :from # who sent the message
    #attr_reader :to # who the message was sent to (usually parsed from params)

    def initialize(client,data)
      @client = client
      @raw_message = data
      parse_message(data)
    end

    def private?
      targeted_message? && @params && @params[0].downcase == @client.config.nick.downcase
    end
    
    def public?
      # change this to check for is_channel?(@params[0])
      !private?
    end
    
    def targeted_message? 
      # add more to this? perhaps!
      @message_type == CMD_PRIVMSG || @message_type == CMD_NOTICE
    end

    def reply(msg, to=nil)
      to ||= public? ? @receiver : @sender
      unless to
        puts "error setting message destination"
        return
      end
      # this is where notify prefs would go
      reply_command(CMD_PRIVMSG, to + ' :' + msg)
    end

    def reply_command(command, params_str)
      @client.send_raw(command + ' ' + params_str)
    end
    
    private

    def parse_message(data)
      @prefix, @message_type, @params = Message.parse_message(data)
      if @prefix
        @sender = @prefix[:hostname] ? @prefix[:hostname] : @prefix[:nick]
      else
        @sender = nil # this should never happen!
        puts "error: sender of message #{data} is invalid"
      end
      if public?
        @receiver = @params[0]
      else
        @receiver = @client.config.nick
      end
    end

  end
end
