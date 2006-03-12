require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/client_commands'
require 'mocks/connection_mock' # connection mock

require 'rubygems'
require 'flexmock' # for generic mocks


# had to create it this way since the bot gets called with .config[something]
class MockClient < FlexMock
  def initialize
    super('mock client')
  end
  def config
    self
  end  
end

class BasicCommandTests < Test::Unit::TestCase
  include IRC
  
  def setup
    @datacmd = DataCommand.new(':server.com PRIVMSG #chan :message')
    @sendcmd = SendCommand.new('send this data')
  end
  
  ##### DataCommand testing
  def test_data_command
    assert_equal :uses_plugins, @datacmd.type
    
    # test that message gets parsed and dispatched to plugins    
    FlexMock.use('mock plugin handler') do |plugin_handler|
      plugin_handler.should_receive(:dispatch).with(Message).once
      @datacmd.execute(plugin_handler)
    end
  end
  
  ##### SendCommand testing
  def test_send_command
    assert_equal :uses_socket, @sendcmd.type
    ConnectionMock.use('connection') do |conn|
      conn.should_receive(:send).with('send this data').once
      @sendcmd.execute(conn)
    end
  end
  
end