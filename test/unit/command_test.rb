require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/command'

class CommandTest < Test::Unit::TestCase
  include IRC
  
  # test command class definition
  class TestCommand < IRCCommand
    # metaprogramming, whee!
    type :test_command
    def execute(arr)
      arr << 'something'
    end
  end

  def test_command_abstract_class
    abstract_command = IRCCommand.new
    assert_raises RuntimeError do
      abstract_command.type
    end
    assert_raises RuntimeError do
      abstract_command.execute
    end
  end
  
  def test_command_metaprogramming
    # assuming no syntax errors in the TestCommand class definition,
    # TestCommand class instances should now have #type defined.
    tc = TestCommand.new
    assert_equal :test_command, tc.type
  end
  
  def test_command_execution
    # test command should expect an array and should add 'something' to it
    arr = []
    tc = TestCommand.new
    tc.execute(arr)
    assert_equal 'something', arr[0]
  end
  
end
