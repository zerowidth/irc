require 'test/unit'
require 'logger'
$:.unshift File.expand_path(File.dirname(__FILE__) + "/../lib")
$:.unshift File.dirname(__FILE__) # for including mocks (require 'mocks/somemock')

require 'rubygems'
require 'active_support/core_ext/kernel/reporting' # for silence_warnings

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
  silence_warnings do
    DEFAULT_LOG_LEVEL = :fatal
  end
end

logger = Logger.new(STDOUT)
logger.level = Logger::FATAL
[IRC::Plugin, IRC::PluginManager].each do |baseclass|
  baseclass.logger ||= logger
end