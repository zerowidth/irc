require 'irc/rfc2812'
require 'irc/cattr_accessor'

module IRC
  class Message
    include IRC # for command consts

    cattr_accessor :logger

    # message parts
    attr_reader :prefix # hash of :nick, :user, :host, :server
    attr_reader :params # broken up into an array based on the command
    attr_reader :sender # who sent the message
    attr_reader :message_type # CMD_*, RPL_*, etc.
    
    attr_reader :raw_message # raw message text, useful for debugging or advanced parsing (heh)
    
    def initialize(prefix,params,sender,message_type,raw_message)
      @prefix, @params, @sender, @message_type, @raw_message =
        prefix, params, sender, message_type, raw_message
    end
    
    def self.parse(data)
      prefix = {}
      params = []
      sender = message_type = nil
      raw_message = data
    
      case data
      when /^:(\S+)\s(\S+)\s(.*)$/
        prefix_data, message_type, message = $~.captures
      when /^([^:]\S+)\s(.*)$/
        message_type, message = $~.captures
      else
        logger.warn "could not parse: #{data}" 
        return
      end

      # parse the prefix. if it doesn't fall into these two categories, then
      # leave the prefix empty (this can happen!)
      if prefix_data =~ /^[^@]+$/ # just the server
        prefix[:server] = prefix_data
      elsif prefix_data =~ /^(\S+)!(\S+)@(\S+)$/
        prefix[:nick], prefix[:user], prefix[:host] = $~.captures        
      end
      
      # that first bit of code acts as a basic (basic!) "correctness" test
      # now, go ahead and set the rest of the stuff
      
      # split up the message around the :
      params, message = message.split(':',2)
      params = params.split(/\s+/)
      params << message if message # in case :<stuff> didn't exist
      
      # this handles both normal messages and direct command messages from the server
      sender = prefix[:server] ? prefix[:server] : 
        ( prefix[:nick] ? prefix[:nick] : params[0] )
      
      Message.new(prefix,params,sender,message_type,raw_message)
    end
  end # class
end
