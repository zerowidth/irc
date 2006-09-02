require File.expand_path(File.dirname(__FILE__) + "/../test_helper")

require 'irc/client'
require 'irc/message'
require 'irc/plugin'
require 'irc/plugin_manager'

class CommonTest < Test::Unit::TestCase
  
  def setup
    @old_logger = IRC::Client.logger
    @log = ''
    @logdev = StringIO.open(@log, 'w')
    @logger = Logger.new(@logdev)
  end
  
  def teardown
    @logdev.close
    each_irc_class do |base|
      base.logger = @old_logger
    end
  end
  
  def test_client_uses_logger
    IRC::Client.logger = @logger
    assert @log.size == 0
    c = IRC::Client.new 
    c.merge_config :host => 'localhost'
    c.start
    assert @log.size > 0
  end

  def test_client_sets_up_delegate_loggers
    each_irc_class { |base| base.logger = nil }
    IRC::Client.logger = @logger
    c = IRC::Client.new
    each_irc_class do |base|
      assert_equal @logger, base.logger, "missing or incorrect logger for #{base}"
    end
  end
  
  def test_client_does_not_override_loggers
    IRC::Connection.logger = 'asdfasdf'
    IRC::Client.logger = @logger
    c = IRC::Client.new
    assert_not_equal(@logger, IRC::Connection.logger)
  end

  def test_client_instantiates_logger_if_not_set
    each_irc_class { |base| base.logger = nil }
    c = IRC::Client.new
    each_irc_class { |base| assert base.logger, "missing logger for #{base}" }
  end

end