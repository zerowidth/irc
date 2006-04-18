require 'test/unit'
require 'logger'
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

logger = Logger.new(STDOUT)
logger.level = Logger::ERROR
[IRC::Plugin, IRC::PluginManager].each do |baseclass|
  baseclass.logger ||= logger
end