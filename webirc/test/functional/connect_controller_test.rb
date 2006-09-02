require File.dirname(__FILE__) + '/../test_helper'
require 'connect_controller'
require "#{RAILS_ROOT}/script/backgroundrb/lib/backgroundrb.rb"
require 'workers/irc_worker'
require 'mock_middleman'
require 'irc/client' # loads the call-recorder mock

class IrcWorker < BackgrounDRb::Rails
  attr_reader :client
end

# Re-raise errors caught by the controller.
class ConnectController; def rescue_action(e) raise e end; end

class ConnectControllerTest < Test::Unit::TestCase
  
  include AuthenticatedTestHelper
  
  fixtures :users, :connection_prefs
  
  def setup
    @controller = ConnectController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new  

    login_as :quentin
  end
  
  def teardown
    MiddleMan.jobs.clear
  end

  # def test_backgroundrb_mock_works
  #   mm = BackgrounDRb::MiddleMan.new
  #   MiddleMan.jobs[:foo] = 'asdf'
  #   two = BackgrounDRb::MiddleMan.new 
  #   assert_equal 'asdf', two[:foo], "uh oh, BackgrounDRb isn't being very testable"
  # end

  def test_index_with_no_prior_prefs
    login_as :arthur # has no connection prefs associated with him
    assert_difference ConnectionPref, :count, 1 do # should create a new ConnectionPref in the db
      get :index
      assert assigns(:connection)
      assert assigns(:connection).valid?, 'default connection should be valid'
      assert_equal DEFAULT_SERVER, assigns(:connection).server, "should create connection with defaults"
      assert_equal 'arthur', assigns(:connection).nick, "should set default to login id if it's a new record"
      assert_response :success
    end
  end

  def test_connect_when_not_connected
    # mm = BackgrounDRb::MiddleMan.new
    assert MiddleMan.jobs.empty?, "middleman has jobs when it shouldn't"
    assert_no_difference ConnectionPref, :count do
      post :index, :connection => 
        {:nick => 'nick', :realname => 'realname', :server => 'server', :port => 6667, :channel => '#chan'}
      assert assigns(:connection)
      assert !MiddleMan.jobs.empty?, "connect controller should have created a new backgroundrb worker"
      assert MiddleMan.jobs['quentin'].client.calls[:start], 'should have called start on the client'
      assert_redirected_to :controller => 'irc', :action => 'index'
    end
  end
  
  def test_forwards_when_connection_active
    # mm = BackgrounDRb::MiddleMan.new
    MiddleMan.new_worker(:class => 'irc_worker', :job_key => 'quentin', :args => {} )
    MiddleMan['quentin'].client.connected=true
    assert_no_difference ConnectionPref, :count do
      get :index
      assert_redirected_to :controller => 'irc', :action => 'index'
    end
  end

  def test_connect_with_errors
    assert_no_difference ConnectionPref, :count do
      post :index, :connection => {:nick => nil, :server => nil} # missing data
      assert assigns(:connection).errors
    end
  end

  def test_login_required
    @request.session[:user] = nil # logout
    assert_requires_login do
      get :index
    end
  end

end
