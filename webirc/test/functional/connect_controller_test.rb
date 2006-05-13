require File.dirname(__FILE__) + '/../test_helper'
require 'connect_controller'

# Re-raise errors caught by the controller.
class ConnectController; def rescue_action(e) raise e end; end

class ConnectControllerTest < Test::Unit::TestCase
  def setup
    @controller = ConnectController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_index
    get :index
    assert assigns(:connection)
    assert assigns(:connection).valid?, 'default connection should be valid'
    assert_equal DEFAULT_NICKNAME, assigns(:connection).nick, "should create connection with defaults"
    assert_success
  end
  
  def test_connect_with_errors
    post :index, :connection => {:nick => 'foo'} # missing data
    assert assigns(:connection).errors
  end
  
  def test_connect
    post :index, :connection => 
      {:nick => 'nick', :realname => 'realname', :server => 'server', :port => 6667, :channel => '#chan'}
      assert session[:connection], 'connection info should be saved in the session'
      assert_redirected_to :controller => 'irc', :action => 'connect'
  end
  
end
