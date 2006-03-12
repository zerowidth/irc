require 'socket'
require 'drb'

$SAFE = 1 # disallow eval() at least

class Test
  include DRbUndumped # prevent full copies of anything from going across the wire
  attr_reader :count
  def initialize
    @count = 0
  end
  
  def ping
    @count += 1
  end
end

acl = 

DRb.install_acl( ACL.new(
  %{deny all 
  allow localhost}
  )
)
DRb.start_service('druby://:10000', Test.new)
DRb.thread.join
