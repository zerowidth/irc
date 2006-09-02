require 'irc/message'
module TestingMessages
  include IRC
  MESSAGES = {
    :welcome => Message.parse('001 :Welcome to the network'),
    :change_own_nick => Message.parse(':nick!~user@server.com NICK :newnick'),
    :other_nick_change => Message.parse(':somenick!~someuser@server.com NICK :somenick2'),
    :nick_in_use => Message.parse(':server.com 433 nick newnick :Nickname already in use'),
    :nick_in_use_during_registration => Message.parse(':server.com 433 * nick :Nickname already in use'),
    :invalid_nick => Message.parse(':server.com 432 nick / :Erroneous Nickname'),
    # colon gets parsed out by server (depends on ircd?), so the message is weird
    :invalid_nick_colon => Message.parse(':server.com 432 nick :Erroneous Nickname'),
    # these two errors comply with RFC, unlike the ircd i tested this with
    :nick_in_use_rfc => Message.parse(':server.com 433 newnickrfc :Nickname already in use'),
    :invalid_nick_rfc => Message.parse(':server.com 432 *rfc :Erroneus Nickname'),
    :ping => Message.parse('PING :server.com'),
    :error => Message.parse('ERROR :Closing Link: 0.0.0.0 (Ping timeout)'),

    :self_join => Message.parse(':nick!~user@server.com JOIN #chan'),
    :other_join => Message.parse(':somedude!~someuser@server.com JOIN #chan'),

    :self_part => Message.parse(':nick!~user@server.com PART #chan :reason'),
    :other_part => Message.parse(':somenick!~someuser@server.com PART #chan :reason'),
    :other_quit => Message.parse(':somenick!~someuser@server.com QUIT :reason'),
    # from trying to track down a bug:
    :freenode_quit => Message.parse(":user!n=user@foo.bar.baz.mumble.net QUIT :"),
    
    :new_topic => Message.parse(':server.com 332 nick #chan :new topic'), # RPL_TOPIC
    :new_topic_rfc => Message.parse(':server.com 332 #chan :new topic'), # RPL_TOPIC (rfc)
    :topic_change => Message.parse(':somenick!~someuser@server.com TOPIC #chan :new topic'),
    
    :names_1 => Message.parse(':server.com 353 nick @ #chan :one @two three'),
    :names_2_rfc => Message.parse(':server.com 353 @ #chan :@four ~five +six'),
    :end_of_names => Message.parse(':server.com 366 nick #chan :end of names list'),
    :end_of_names_rfc => Message.parse(':server.com 366 #chan :end of names list'),
    
    :privmsg => Message.parse(':somenick!~someuser@server.com PRIVMSG #chan :hello'),
    :privmsg_private => Message.parse(':somenick!~someuser@server.com PRIVMSG nick :hello'),
    :privmsg_private_mixed_case => Message.parse(':somenick!~someuser@server.com PRIVMSG NiCk :hello'),
    :privmsg_action => Message.parse(":somenick!~someuser@server.com PRIVMSG #chan :\001ACTION hello\001"),

    :notice => Message.parse(':somenick!~someuser@server.com NOTICE #chan :hello'),
    :notice_private => Message.parse(':somenick!~someuser@server.com NOTICE nick :hello'),
    :notice_server => Message.parse(':server.com NOTICE nick :hello'),
    #
    # :welcome => Message.parse(':server.com 001 :Welcome to the network'),
    #
    # :unknown => Message.parse(':server.com 210 :RPL_TRACERECONNECT is unused')
    
  }.freeze
  def message(name)
    raise "invalid message specified :#{name}" unless MESSAGES[name]
    MESSAGES[name]
  end
  def raw_message(name)
    message(name).raw_message
  end
end