require File.dirname(__FILE__) + '/../test_helper'
require 'irc_controller'
require 'workers/irc_worker'

class IrcWorker < BackgrounDRb::Rails
  attr_reader :work_thread, :client
end

# Re-raise errors caught by the controller.
class IrcController; def rescue_action(e) raise e end; end

class IrcControllerTest < Test::Unit::TestCase
  fixtures :users, :connection_prefs
  include AuthenticatedTestHelper # for user login, which is used here for client identification
  
  def setup
    @controller = IrcController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    
    login_as :quentin

    MiddleMan.new_worker(:class => 'irc_worker', :job_key => 'quentin', :args => {})
    MiddleMan.jobs['quentin'].work_thread.join # wait for it to start up
    @client = MiddleMan['quentin'].client
    @client.start
    @client.state[:events] ||= []
    @client.state[:topics] = {'#chan' => ''}
    # @client.state[:nick] = 'nick'
  end

  def teardown
    MiddleMan.jobs.clear # BackgrounDRb::MiddleMan.new.jobs.clear
  end
  
  def test_redirect_when_not_connected
    MiddleMan.jobs.clear
    get :index
    assert_redirected_to :controller => 'connect', :action => 'index'
  end

  def test_index_when_connected
    get :index
    assert_response :success
    assert_nil session[:last_event]
    5.times { @client.state[:events] << IRC::Event.new }
    get :index
    assert_response :success
    assert assigns(:events), 'should assign @events'
    assert_equal 5, assigns(:events).size, 'there should be 5 events'
    assert_equal @client.state[:events].last.id, session[:last_event]
  end
  
  def test_disconnect
    get :disconnect
    assert_redirected_to :controller => 'connect'
    assert ! MiddleMan.jobs['quentin'], 'job should be deleted'
  end
  
  def test_disconnect_xhr
    xhr :get, :disconnect
    assert_response :success
    assert ! MiddleMan.jobs['quentin'], 'job should be deleted'
    assert_rjs :redirect_to, :controller => 'connect'
  end
  
  def test_update_redirect_when_no_worker
    MiddleMan.jobs.clear
    xhr :get, :update
    assert_rjs :redirect_to, :controller => 'connect', :action => 'index'  
  end
  
  def test_update_redirects_when_disconnected
    @client.connected = false
    xhr :get, :update
    assert_rjs :redirect_to, :controller => 'connect', :action => 'index'  
  end
  
  # ----- user input testing (input box)
  def test_basic_input
    xhr :post, :input, {:input => 'lol'}
    assert_response :success
    assert @client.calls[:channel_message], 'should have sent a channel message'
    # TODO test non-xhr
  end
  
  def test_nick_change
    xhr :post, :input, :input => '/nick newnick'
    assert_equal ['newnick'], @client.calls[:change_nick].first
    # TODO add invalid/in-use nick handling to state manager!
  end
    
  def test_empty_nick_change # nil is accepted
    xhr :post, :input, :input => '/nick'
    assert_equal [nil], @client.calls[:change_nick].first # will cause error on irc side, but that's ok
  end
    
  def test_quit_command
    xhr :post, :input, :input => '/quit'
    assert @client.calls[:quit], 'should have sent quit message'
    assert_rjs :redirect_to, :controller => 'connect'
  end
    
  def test_quit_with_reason
    xhr :post, :input, :input => '/quit bye'
    assert_equal ['bye'], @client.calls[:quit].first
  end
  
  def test_nonhandled_slashes_fall_through
    xhr :post, :input, :input => '/foo text'
    assert_equal ['#chan','/foo text'], @client.calls[:channel_message].first
  end
  
  def test_slash_me
    xhr :post, :input, :input => '/me ' #empty!
    assert_nil @client.calls[:channel_message]
    xhr :post, :input, :input => '/me action'
    assert_equal ['#chan', "\001ACTION action\001"], @client.calls[:channel_message].first
  end
    
  # ----- ajax testing
  def test_update
    5.times { @client.state[:events] << IRC::Event.new }
    @request.session[:last_event] = @client.state[:events][2].id
    xhr :get, :update
    assert_response :success
    assert assigns(:events)
    assert_equal @client.state[:events][3], assigns(:events).first
    assert_equal @client.state[:events].last, assigns(:events).last
    assert_equal @client.state[:events].last.id, session[:last_event]
    assert_xhr_only :update
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
    BackgrounDRb::MiddleMan.new.jobs.clear
    get action
    assert_response :redirect
  end
  
end
