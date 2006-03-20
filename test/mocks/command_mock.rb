require 'rubygems'
require 'flexmock'

class CommandMock < FlexMock
  undef :type # .type is overridden by Commands
end