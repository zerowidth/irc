require 'backgroundrb'
#require "#{RAILS_ROOT}/script/backgroundrb/lib/backgroundrb.rb"
require 'irc/client'
#require 'workers/irc_worker'

class ConnectController < ApplicationController
  
  include AuthenticatedSystem
  before_filter :login_required
  
  layout 'irc'
  
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
      # should redirect, not succeed (? this made sense once)
    end

    @connection = current_user.connection_pref # for the view

    worker = MiddleMan.get_worker(current_user.login)
    if worker && worker.connected?
      redirect_to :controller => 'irc', :action => 'index' and return
    end

    if request.post?
      @connection.attributes = params[:connection]
      if @connection.save
        unless worker
          MiddleMan.new_worker(:class => 'irc_worker', 
            :job_key => current_user.login, 
            :args => current_user.connection_pref.to_hash )
          worker = MiddleMan.get_worker(current_user.login)
        end
        worker.autojoin current_user.connection_pref.channel
        worker.start
        redirect_to :controller => 'irc', :action => 'index' if worker.connected?
      end
    end
    
    # TODO error checking uaa

  end
  
end
