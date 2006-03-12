require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
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
      rescue Config::ConfigOptionRequired # ignore required
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
  
  # i don't think this is fully explored. i originally wrote this test having
  # defaults[:channels] set to an empty array, which was then modified when
  # @config[:channels] was modified. no good at all. i wonder if there's a
  # way to deep-clone the config, including arrays? maybe...
  def test_defaults_arent_modified
    @config[:channels] = ['test']
    assert_equal ['test'], @config[:channels]
    assert_equal nil, Config::CONFIG_DEFAULTS[:channels]
  end
  
  # now some interesting bits.
  # the server will return a NICK command when changing a nick after the fact
  # however... that won't happen when registering (and there's a nick collision)
  # furthermore, anytime the nick is being changed, for concurrency's sake, 
  # the previous (and potentially still active) nick needs to be kept around in
  # case the new nickame doesn't work out, and in case other messages addressed
  # to the client come in in the meantime (need to have message know for sure
  # whether or not a message is directed to the client or not)
  # 
  # lastly, this will work *even if* multiple nick changes in a row are attempted.
  # the client (test this) should set :oldnick = :nick, which will still be :oldnick,
  # if multiple nick changes are attempted.
  def test_nick_and_oldnick
    # check for the default first
    assert_equal 'rbot', @config[:nick]
    # set a new nick, and check that it's valid
    @config[:nick]='rbot2'
    assert_equal 'rbot2', @config[:nick]
    # ok, that was the easy part. now, what happens if a nick gets changed?
    # anything changing the nick (including registration) should set 
    # oldnick. if a "success" message is ever returned, oldnick should be set to nil.
    # hrm, success could be either CMD_NICK or perhaps an RPL_WELCOME
    # 
    # so here's the test: until oldnick is removed, return oldnick 
    @config[:oldnick] = 'rbot'
    @config[:nick] = 'rbot2'
    assert_equal 'rbot', @config[:nick]
    @config[:oldnick] = nil
    assert_equal 'rbot2', @config[:nick]
  end
  
end