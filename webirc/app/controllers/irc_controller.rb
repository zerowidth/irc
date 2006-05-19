require 'irc/event'
class IrcController < ApplicationController
  include AuthenticatedSystem # TODO move this to ApplicationController
  before_filter :login_required
  
  def index
    client = Client.new(current_user.id)
    redirect_to :controller => 'connect', :action => 'index' and return unless client.connected?
    @events = client.events
    session[:last_event] = @events.last.id if @events && @events.size > 0
    render_text 'asdf'
  end
  
  def connect
    connection = current_user.connection_pref
    client = Client.new(current_user.id)
    redirect_to :controller => 'connect', :action => 'index' and return unless connection
    unless client.connected?
      client.connect(connection)
    end
    redirect_to :action => 'index'
  end
end
