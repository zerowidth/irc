class IrcController < ApplicationController
  include AuthenticatedSystem # TODO move this to ApplicationController
  
  def index
    client = Client.new(current_user)
    redirect_to :controller => 'connect', :action => 'index' and return unless client.connected?
    render_text 'asdf'
  end
  
  def connect
    render_text 'asdf'
  end
end
