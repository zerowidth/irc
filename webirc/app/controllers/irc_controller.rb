class IrcController < ApplicationController
  include AuthenticatedSystem # TODO move this to ApplicationController
  before_filter :login_required
  
  def index
    client = Client.new(current_user)
    redirect_to :controller => 'connect', :action => 'index' and return unless client.connected?
    render_text 'asdf'
  end
  
  def connect
    connection = current_user.connection_pref
    client = Client.new(current_user)
    redirect_to :controller => 'connect', :action => 'index' and return unless connection
    unless client.connected?
      client.connect(connection)
    end      
    redirect_to :action => 'index'
  end
end
