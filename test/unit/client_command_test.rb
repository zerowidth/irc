require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/client_commands'

class BasicCommandTests < Test::Unit::TestCase
  include IRC
  
  def setup
    @datacmd = DataCommand.new('insert valid message here, once Message is written...')
  end
  
  ### DataCommand testing
  def test_data_command
    assert_equal :uses_plugins, @datacmd.type
    
    # test that message gets parsed and dispatched to plugins
    
    # will need a stub/mock plugin handler
    
  end
  
  
  
end