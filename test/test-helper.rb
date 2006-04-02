require 'test/unit'
$:.unshift File.expand_path(File.dirname(__FILE__) + "/../lib")
$:.unshift File.dirname(__FILE__) # for including mocks (require 'mocks/somemock')

puts "loading test helper"

# load the irc files
require 'irc/client'

# extension of Test::Unit assertions
module Test::Unit::Assertions
  def assert_false boolean, msg = nil
    assert_equal false, boolean, msg
  end
end

# override the default log level
module IRC
  DEFAULT_LOG_LEVEL = :error
end