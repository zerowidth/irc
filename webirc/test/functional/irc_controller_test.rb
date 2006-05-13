require File.dirname(__FILE__) + '/../test_helper'
require 'irc_controller'

# Re-raise errors caught by the controller.
class IrcController; def rescue_action(e) raise e end; end

class IrcControllerTest < Test::Unit::TestCase
  def setup
    @controller = IrcController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
