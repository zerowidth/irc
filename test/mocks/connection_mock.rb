require 'rubygems'
require 'flexmock'

class ConnectionMock < FlexMock
  undef :send
end