class ConnectController < ApplicationController
  
  include AuthenticatedSystem
  before_filter :login_required
  
  layout 'irc'
  model :connection_pref
  
  def index
    @connection = current_user.connection_pref || connection_with_defaults
    if request.post?
      @connection.attributes = params[:connection]
      redirect_to :controller => 'irc', :action => 'connect' if @connection.save
    end
  end
  
  private
  
  def connection_with_defaults
    ConnectionPref.new( 
      :user_id => current_user.id,
      :nick => DEFAULT_NICKNAME,
      :realname => DEFAULT_REALNAME,
      :server => DEFAULT_SERVER,
      :port => DEFAULT_PORT,
      :channel => DEFAULT_CHANNEL
    )
  end
end
