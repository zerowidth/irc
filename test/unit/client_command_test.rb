require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/client_commands'
require 'mocks/connection_mock' # connection mock
require 'stubs/command_queue_stub' # command queue stub

require 'rubygems'
require 'flexmock' # for generic mocks

# reveal internals for easy testing
class IRC::SendCommand
  attr_reader :data
end

class ClientCommandTests < Test::Unit::TestCase
  include IRC
  
  def setup
    @datacmd = DataCommand.new(':server.com PRIVMSG #chan :message')
    @sendcmd = SendCommand.new('send this data')
    @quitcmd = QuitCommand.new('reason')
    @regcmd = RegisterCommand.new('nick','user','realname')
    @nickcmd = NickCommand.new('newnick')
    @joincmd = JoinCommand.new('#channel')
    @partcmd = PartCommand.new('#channel')
    
    # stubs:
    @cq = CommandQueueStub.new
    @config = {}
    @state = {}
  end
  
  def test_data_command
    assert @datacmd.is_a?(PluginCommand)
    
    # test that message gets parsed and dispatched to plugins    
    FlexMock.use('mock plugin handler') do |plugin_handler|
      plugin_handler.should_receive(:dispatch).with(Message).once
      @datacmd.execute(plugin_handler)
    end
  end
  
  def test_send_command
    assert @sendcmd.is_a?(SocketCommand)
    assert_equal 'send this data', @sendcmd.data # .data accessor (easier for testing)
    ConnectionMock.use('connection') do |conn|
      conn.should_receive(:send).with('send this data').once
      @sendcmd.execute(conn)
    end
  end
  
  def test_quit_command
    assert @quitcmd.is_a?(ClientCommand)
    FlexMock.use('client mock') do |client|
      client.should_receive(:quit).with('reason').once
      @quitcmd.execute(client)
    end # verifies the mock's expectations
  end
  
  def test_register_command
    assert @regcmd.is_a?(QueueCommand)
    assert @cq.empty?
    @regcmd.execute(@cq)
    assert_equal 2, @cq.queue.size
    assert_equal 'USER user 0 * :realname', @cq.queue[0].data
    assert_equal NickCommand, @cq.queue[1].class
  end
  
  def test_nick_command
    assert @nickcmd.is_a?(QueueConfigStateCommand)
    assert @cq.empty?
    assert_equal nil, @state[:newnick]
    @nickcmd.execute(@cq,@config,@state)
    assert_equal SendCommand, @cq.queue[0].class
    assert_equal 'NICK newnick', @cq.queue[0].data
    # make sure it saved the new nick by adding it to the new nick list
    assert_equal ['newnick'], @state[:newnick]
  end
  
  def test_join_command
    assert_command_sends @joincmd, 'JOIN #channel'
  end
  
  def test_part_command
    assert_command_sends @partcmd, 'PART #channel'
  end

  # helper to make testing of basic queue commands easier
  def assert_command_sends(cmd, data)
    assert cmd.is_a?(QueueCommand)
    assert @cq.empty?
    cmd.execute(@cq)
    assert_equal SendCommand, @cq.queue[0].class
    assert_equal data, @cq.queue[0].data
  end

end