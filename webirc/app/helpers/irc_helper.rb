module IrcHelper
  def irc_timestamp(time)
    span_class('timestamp', time.strftime( '[%H:%M:%S]' ) )
  end
  
  def span_class(classname, text)
    %Q{<span class="#{classname}">#{text}</span>}
  end
  
  def irc_who(event)
    case event.context
    when :server
      span_class('server', "*#{event.who}*")
    when :self
      span_class('self', "&lt;#{event.who}&gt;")
    else
      span_class('nick', "&lt;#{event.who}&gt;")
    end + ' '
  end
  
  def irc_action_who(event)
    span_class('action', "* #{event.who} ")
  end
  
  def irc_privmsg(event)
    msg = event.what
    msg.gsub!(/(\003\d{0,2}|\002|\037)/, '') # TODO: handle CTCP, test that BOLD gets stripped, etc.
    if msg =~ /\001ACTION (.*)\001/
      msg = $1 
      irc_action_who(event) + span_class('action', h(msg) )
    else
      irc_who(event) + span_class('privmsg', h(msg) )
    end
  end
end
