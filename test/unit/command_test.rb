require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/command'
require 'irc/client_commands' # so SendCommand is available
require 'irc/rfc2812'
require 'stubs/command_queue_stub'

class CommandTest < Test::Unit::TestCase
  include IRC
  
  # test command class definitions
  class TestCommand < IRCCommand
    def execute(arr)
      arr << 'something'
    end
  end

  class TestMetaprogrammedQueueCommand < QueueCommand
    include IRC # prevent some scoping weirdness within the test
    simple_queue_command CMD_PRIVMSG
  end

  def test_command_abstract_classes
    [IRCCommand, ClientCommand, SocketCommand, 
     PluginCommand, QueueCommand, QueueConfigStateCommand].each do |abstract|
      abstract_command = abstract.new
      assert_raises NoMethodError do
        abstract_command.execute(:somearg)
      end
    end
  end

  def test_simple_queue_command_metaprogramming
    assert_raises ArgumentError do
      qc = TestMetaprogrammedQueueCommand.new
    end
    command_queue = QueueStub.new
    qc = TestMetaprogrammedQueueCommand.new('data')
    assert qc.is_a?(QueueCommand)
    assert_equal 1, qc.method(:execute).arity
    assert command_queue.empty?
    qc.execute(command_queue)
    assert_false command_queue.empty?
  end
  
  def test_command_execution
    # test command should expect an array and should add 'something' to it
    arr = []
    tc = TestCommand.new
    tc.execute(arr)
    assert_equal 'something', arr[0]
  end
  
end
