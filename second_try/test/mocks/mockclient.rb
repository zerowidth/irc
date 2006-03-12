require 'rubygems'
require 'flexmock'

# had to create it this way since the bot gets called with .config[something]
class MockClient < FlexMock
  def initialize
    super('mock client')
  end
  def config
    self
  end  
end