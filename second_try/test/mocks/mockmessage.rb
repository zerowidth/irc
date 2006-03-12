require 'rubygems'
require 'flexmock'

# mocked so .client is available for client modification testing
# also so attr hashes can get called
class MockMessage < FlexMock
  def initialize
    @type = nil
    super('mock message')
  end
  
  # this is copied and simplified from MockServer
  def mock(&block)
    yield
    self.mock_verify
  end
  
  def client; self; end # message.client
  #def config; self; end # message.client.config
  #def channels; self; end; # message.client.channels
  def params; self; end # message.params
  def prefix; self; end # message.prefix
end