require 'rubygems'
require 'flexmock'
require 'pp'

FlexMock.use('foo') do |m|
  m.should_receive(:a).ordered(1).once
  m.should_receive(:b).ordered(2).once
  m.should_receive(:a).ordered(3).once # this never gets called.
  # the reason is, flexmock's expectations match via "first found, in order"
  # because :a is set as order 1, the second time a gets called it's considered
  # starting over! fuck, that's not helpful :(
  
  m.a
  m.b
  m.a

end
