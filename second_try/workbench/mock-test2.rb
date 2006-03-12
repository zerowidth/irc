require 'rubygems'
require 'flexmock'

@f = FlexMock.new('foo')
def doblock(&blk)
  yield @f
end

doblock do |m| 
  m.should_receive(:foo).twice
  m.foo
  @f.mock_verify
end