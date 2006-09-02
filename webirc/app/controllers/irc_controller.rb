#require "#{RAILS_ROOT}/script/backgroundrb/lib/backgroundrb.rb"
require 'backgroundrb'
require 'irc/client'
require 'irc/event'

class IrcController < ApplicationController
  include AuthenticatedSystem # TODO move this to ApplicationController
  before_filter :login_required
  
  def index
    worker = MiddleMan[current_user.login]
    unless worker && worker.connected?
      redirect_to :controller => 'connect', :action => 'index' and return
    end
    @events = worker.events
    session[:last_event] = @events.last.id if @events && @events.size > 0
  end
  
  def update
    # TODO update should redirect if disconnected! ya srsly! with a flash message too
    redirect_to :action => 'index' and return unless request.xhr?
    update_events
  end
  
  def disconnect
    worker = MiddleMan[current_user.login]
    if worker
      worker.quit('client disconnected') 
      MiddleMan.delete_worker(current_user.login)
    end
    if request.xhr?
      render :update do |page|
        page.redirect_to :controller => 'connect', :action => 'index'
      end
    else
      redirect_to :controller => 'connect', :action => 'index' and return
    end
  end
  
  def input
    handle_input(params['input'])
    # TODO yeah /quit should actually quit
    if @quit
      render :update do |page|
        page.redirect_to :controller => 'connect', :action => 'index'
      end
    else
      update_events
    end
  end

  private
  
  def update_events
    worker = MiddleMan[current_user.login]
    if worker && worker.connected?
      @events = worker.events_since session[:last_event]
      session[:last_event] = @events.last.id if @events && @events.size > 0
      render :partial => 'update_events', :locals => { :events => @events }      
    else
      render :update do |page|
        page.redirect_to :controller => 'connect', :action => 'index'
      end
    end
  end

  def handle_input(input)
    client = MiddleMan[current_user.login]
    return unless client && client.connected? # TODO test this
    if input =~ /^\/(\w+)(\s+(.*))?/i # for /foo bar baz, $1 is /foo, $3 is 'bar baz', for '/foo'
      case $1
      when 'me'
        client.channel_message(client.state[:topics].keys.first, "\001ACTION #{$3}\001") unless $3.nil? or $3.empty?
      when 'nick'
        logger.info 'trying to change nick'
        client.change_nick($3) # nil accepted
      when 'quit'
        client.quit($3) # nil is accepted
        @quit = true
      else
        client.channel_message(client.state[:topics].keys.first, input)
      end
    elsif input.size > 0
      client.channel_message(client.state[:topics].keys.first, input)
    end
  end

end
