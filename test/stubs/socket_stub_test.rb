require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'stubs/socket_stub'

class SocketStubTest < Test::Unit::TestCase

  def setup
    SocketStub.server_connected = true
    @s = SocketStub.open(nil,nil)
  end
  
  def test_basic
    data = nil
    t = Thread.new { data = @s.gets } # blocking call
    assert t.alive?, 'gets should be blocking' # shouldn't be dead yet
    @s.server_puts 'lol'
    t.join
    assert data, 'basic gets should have received data!'
  end

  def test_ioerror
    t = Thread.new { @s.gets } 
    @s.server_close
    assert_raises IOError do
      t.join
    end
  end

  def test_connrefused
    SocketStub.server_connected = false
    rescued = false
    begin
      s = SocketStub.open(nil, nil)
    rescue Errno::ECONNREFUSED
      rescued = true
    end
    assert rescued, 'server connected false should cause an error when connecting'
  end
  
end