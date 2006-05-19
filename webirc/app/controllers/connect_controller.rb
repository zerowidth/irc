class ConnectController < ApplicationController
  
  include AuthenticatedSystem
  before_filter :login_required
  
  layout 'irc'
  model :connection_pref
  
  def index
    unless current_user.connection_pref
      current_user.connection_pref = ConnectionPref.new_with_defaults :nick => current_user.login 
    end
    @connection = current_user.connection_pref
    if request.post?
      @connection.attributes = params[:connection]
      redirect_to :controller => 'irc', :action => 'connect' if @connection.save
    end
  end
  
end