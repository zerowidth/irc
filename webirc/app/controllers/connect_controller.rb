class ConnectController < ApplicationController
  
  include AuthenticatedSystem
  before_filter :login_required
  
  layout 'irc'
  model :connection_pref
  
  # methods:
  # get: first access
  #   - check that a connection is accessible/available or not
  #   - if so, redirect to irc/index
  # post
  #   - validate connection
  #   - display errors OR
  #   - establish connection and redirect to irc controller
  def index
    unless current_user.connection_pref
      current_user.connection_pref = ConnectionPref.new_with_defaults :nick => current_user.login
    end

    @connection = current_user.connection_pref
    client = Client.for current_user

    if client.connected?
      redirect_to :controller => 'irc', :action => 'index' and return
    end

    if request.post?
      @connection.attributes = params[:connection]
      redirect_to :controller => 'irc', :action => 'index' if @connection.save
    end
  end
  
end
