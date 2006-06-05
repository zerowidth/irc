require File.dirname(__FILE__) + '/../test_helper'
require 'irc_controller'

# This is kind of an odd situation: I'd prefer to use a Client mock selectively for just
# the irc_controller test, but since it reopens the model class, it affects everything else.
# The Client unit testing relies on setting up a mock manager on the remote end of a
# DRb server, so the DRb service will need to be initialized anywhere the client is being
# used in a test.
# ==> End result is, I've had to push anything that I needed to set selectively
# (connected flag) down to the mock manager level (or the mock proxy object). no big deal

# Re-raise errors caught by the controller.
class IrcController; def rescue_action(e) raise e end; end

class IrcControllerTest < Test::Unit::TestCase
  fixtures :users, :connection_prefs
  include AuthenticatedTestHelper # for user login, which is used here for client identification
  
  def setup
    @controller = IrcController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    
    # set up the mock for the client
    @proxy = MockProxy.new
    @manager = MockManager.new @proxy
    DRb.start_service(Client.drb_uri, @manager)
    
    # set the current user
    login_as :quentin
  end

  def teardown
    DRb.stop_service
  end

  def test_redirect_when_not_connected
    @proxy.running = false
    get :index
    assert_redirected_to :controller => 'connect', :action => 'index'
  end

  def test_index_when_connected
    @proxy.running = true
    get :index
    assert_success
    assert assigns(:events), 'should assign @events'
    assert_equal users(:quentin).id, @manager.calls[:client].first[0]
    assert_nil session[:last_event]
    5.times { @proxy.add_event IRC::Event.new }
    get :index
    assert_success
    assert assigns(:events), 'should assign @events'
    assert_equal 5, assigns(:events).size, 'there should be 5 events'
    assert_equal @proxy.events.last.id, session[:last_event]
  end
  
  # ----- ajax testing
  def test_update
    assert_xhr_only :update
    5.times { @proxy.add_event IRC::Event.new }
    session[:last_event] = @proxy.events[2].id
    xhr :get, :update
    assert_success
    assert assigns(:events)
    assert_equal @proxy.events[3], assigns(:events).first
    assert_equal @proxy.events.last, assigns(:events).last
    assert_equal @proxy.events.last.id, session[:last_event]
  end
  
  # ----- etc.

  def test_login_required
    @request.session[:user] = nil
    assert_requires_login do
      get :index
    end
  end
  
  # ---- helpers
  
  def assert_xhr_only(action)
    get action
    assert_response :redirect
  end
  
end
