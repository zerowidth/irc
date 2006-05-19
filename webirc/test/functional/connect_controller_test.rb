require File.dirname(__FILE__) + '/../test_helper'
require 'connect_controller'

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

  def test_index_with_no_prior_prefs
      login_as :arthur # has no connection prefs associated with him
      assert_difference ConnectionPref, :count, 1 do # should create a new ConnectionPref in the db
        get :index
        assert assigns(:connection) 
        assigns(:connection).errors
        assert assigns(:connection).valid?, 'default connection should be valid'
        assert_equal DEFAULT_SERVER, assigns(:connection).server, "should create connection with defaults"
        assert_equal 'arthur', assigns(:connection).nick, "should set default to login if it's a new record"
        assert_success
    end
  end
  
  def test_connect_with_errors
    assert_no_difference ConnectionPref, :count do
      post :index, :connection => {:nick => nil, :server => nil} # missing data
      assert assigns(:connection).errors
    end
  end
  
  def test_connect
    assert_no_difference ConnectionPref, :count do
      post :index, :connection => 
        {:nick => 'nick', :realname => 'realname', :server => 'server', :port => 6667, :channel => '#chan'}
      assert_redirected_to :controller => 'irc', :action => 'connect'
    end
  end
  
  def test_login_required
    @request.session[:user] = nil # logout
    assert_requires_login do
      get :index
    end
  end
  
end
