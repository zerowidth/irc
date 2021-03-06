require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'irc/config'

class ConfigTest < Test::Unit::TestCase
  include IRC
  
  # rake requires 'rbconfig', which defines a module Config, which overrides
  # IRC::Config even though IRC is included here. So, to give module Config the boot,
  # i'm redefining a class Config in the local scope. yay for dynamic redefinition!
  class Config < IRC::Config; end;
  
  def setup
    @config = Config.new
  end
  
  def test_defaults_loaded
    Config::CONFIG_DEFAULTS.each_pair do |key, val|
      begin
        assert_equal val, @config[key]
      rescue Config::ConfigOptionRequired # ignore required configuration options
      end
    end
  end
  
  def test_config_should_throw_exception_for_required
    assert_raise(Config::ConfigOptionRequired) do
      @config[:host]
    end
    assert_raise(Config::ConfigOptionRequired) do
      @config.exception_unless_configured
    end
  end
  
  def test_config_setting_and_getting
    assert_equal 6667, @config[:port] # default
    @config[:port] = 10000
    assert_equal 10000, @config[:port]
  end
  
  def test_readonly
    assert_false @config.readonly?
    @config.readonly!
    assert @config.readonly?
    assert_raise RuntimeError do
      @config[:host]='whatev'
    end
  end
  
  def test_writeable
    assert_false @config.readonly?
    @config.readonly!
    assert @config.readonly?
    @config.writeable!
    assert_false @config.readonly?
  end

  # don't need to test the default, which doesn't load from file. this is handled
  # above in the defaults test.
  def test_load_from_file
    @config = Config.new('test/fixtures/config.yaml') # load from test config file
    assert_equal 10000, @config[:port] # only entry in config file
  end

  def test_load_from_nonexistent_file
    assert_raise(Errno::ENOENT) do
      @config = Config.new('nonexistent-configfile.yaml')
    end
  end
  
  def test_config_merge
    assert_equal 6667, @config[:port]
    @config.merge!( {:port=>10000} )
    assert_equal 10000, @config[:port]
  end

end
