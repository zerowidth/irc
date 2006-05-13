class ConnectController < ApplicationController
  layout 'irc'
  model :connection # non-AR model with validations
  
  def index
    # get the previous connection if there's errors, or create a new one with the defaults
    @connection = params[:connection] ? Connection.new(params[:connection]) : Connection.new(
      :nick => DEFAULT_NICKNAME,
      :realname => DEFAULT_REALNAME,
      :server => DEFAULT_SERVER,
      :port => DEFAULT_PORT,
      :channel => DEFAULT_CHANNEL
      )
    # validate is called always, so errors are accessible if not postback
    if @connection.valid? && request.post?
      session[:connection] = @connection
      redirect_to :controller => 'irc', :action => 'connect'
    end
  end
end
