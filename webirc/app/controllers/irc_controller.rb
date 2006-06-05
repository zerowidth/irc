require 'irc/event'
require 'irc/client_commands'

class IrcController < ApplicationController
  include AuthenticatedSystem # TODO move this to ApplicationController
  before_filter :login_required
  
#   def connect
#     connection = current_user.connection_pref
#     client = Client.new(current_user.id)
#     redirect_to :controller => 'connect', :action => 'index' and return unless connection
#     unless client.connected?
#       client.connect(connection)
#     end
#     redirect_to :action => 'index'
#   end

  def index
    client = Client.for current_user
    redirect_to :controller => 'connect', :action => 'index' and return unless client.connected?
    @events = client.events
    session[:last_event] = @events.last.id if @events && @events.size > 0
  end
  
  def update
    redirect_to :action => 'index' and return unless request.xhr?
    client = Client.for current_user
    @events = client.events_since session[:last_event]
    session[:last_event] = @events.last.id if @events.size > 0
    render :partial => 'update_events', :locals => { :events => @events }
  end
  
  def input
    redirect_to :action => 'index' and return unless request.xhr?
    handle_input(params['input'])
    #events = client.events_since session[:last_event]
    render_nothing
  end
  
  private
  
  def handle_input(input)
    client = Client.for current_user
    if input =~ /^\/(\w+)(\s+(.*))?/i # for /foo bar baz, $1 is /foo, $3 is 'bar baz'
      case $1
      when 'join'
#        logger.info "joining #{$3}"
        client.add_command IRC::JoinCommand.new($3)
      when 'nick'
        client.add_command IRC::NickCommand.new($3)
      when 'quit'
        client.quit $3
      end
    elsif input.size > 0
logger.info "PRIVMSG #{client.state(:topics).keys.first} :#{input}"
cmd = IRC::SendCommand.new("PRIVMSG #{client.state(:topics).keys.first} :#{input}")
logger.info cmd.inspect
      client.add_command cmd
    end
  end

end
