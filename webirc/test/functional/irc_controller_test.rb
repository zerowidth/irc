require File.dirname(__FILE__) + '/../test_helper'
require 'irc_controller'
require 'mockmanager'

# This is kind of an odd situation: I'd prefer to use a Client mock selectively for just
# the irc_controller test, but since it reopens the model class, it affects everything else.
# The Client unit testing relies on setting up a mock bot manager on the remote end of a
# DRb server, so the DRb service will need to be initialized anywhere the client is being
# used in a test.
# ==> End result is, I've had to push anything that I needed to set selectively
# (connected flag) down to the mock manager level.

# Re-raise errors caught by the controller.
class IrcController; def rescue_action(e) raise e end; end

class IrcControllerTest < Test::Unit::TestCase
  fixtures :users
  include AuthenticatedTestHelper # for user login, which is used here for client identification
  
  def setup
    @controller = IrcController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    
    # set up the mock for the client
    @manager = MockManager.new
    DRb.start_service(Client.drb_uri, @manager)
    
    # set the current user
    login_as :quentin
  end
  
  def teardown
    DRb.stop_service
  end

  def test_index_when_not_connected
    @manager.client_running = false
    get :index
    assert_redirected_to :controller => 'connect'
  end
  
  def test_index_when_connected
    @manager.client_running = true
    get :index
    assert_success
  end

  def test_connect
    get :connect
  end
end
