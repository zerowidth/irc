require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'irc/plugin_manager'

class PluginManagerTest < Test::Unit::TestCase
  include IRC
  
  # test plugin, records that methods get called or not (this was easier than a mock)
  class CallRecorderPlugin < Plugin
    def self.count
      @@count || {}
    end
    def self.reset_count
      @@count = {}
    end
    
    def privmsg(msg)
      record_call(msg.message_type)
    end
    
    def m001(msg)
      record_call(msg.message_type)
    end
    
    def catchall(msg)
      record_call :catchall
    end
    
    def initialize(*args)
      super(*args)
      record_call(:startup)
    end
    
    def teardown
      record_call(:teardown)
    end
    
    private 
    def record_call(type)
      @@count ||= {}
      @@count[type] ||= 0
      @@count[type] += 1
    end
  end
  
  class DuplicatePluginOne < CallRecorderPlugin; 
    def m123 msg
      record_call :m123
    end
  end
  class DuplicatePluginTwo < CallRecorderPlugin; end
  
  # raises an exception, to test how dispatch code handles exceptions
  class NastyPlugin < Plugin
    def privmsg(msg)
      raise 'KABOOM'
    end
    def m001(msg)
      sleep 5
    end
    def m123 # incorrect arity!
    end
  end
  
  # expose the guts of plugin manager for thorough testing
  # otherwise it's pretty much a mysterious black box with a minimal interface
  class IRC::PluginManager
    attr_reader :plugins, :threads, :janitor # janitor thread
    public :method_for
    def self.plugins; @@plugins || []; end
    def self.reset_plugins; @@plugins = []; end # for testing registration code
  end

  def setup
    
    CallRecorderPlugin.reset_count
    PluginManager.reset_plugins
    
    @private_privmsg = Message.parse ':nathan!~nathan@subdomain.domain.net PRIVMSG rbot :hello there!'
    @general_server_message = Message.parse ':server.com 001 rbot :Welcome to the network: dude!'
    @unknown_message = Message.parse ':server.com 123 rbot :who knows what this is'
    @unknown_message_two = Message.parse ':server.com 124 rbot :who knows what this is'

  end
  
  def test_registration
    # test that plugin registrations get stored in the class singleton
    assert_equal 0, PluginManager.plugins.size
    PluginManager.register_plugin CallRecorderPlugin
    assert_equal 1, PluginManager.plugins.size
  end
  
  def test_instantiation
    # instantiation of the plugin manager class should "freeze" the plugin list
    # by instantiating everything
    PluginManager.register_plugin CallRecorderPlugin
    PluginManager.register_plugin NastyPlugin
    assert_equal 2, PluginManager.plugins.size
    # instantiate it
    pm = PluginManager.new(nil,nil,nil)
    # check its guts
    assert_equal 2, pm.plugins.size
  end
  
  def test_duplicate_registrations_instantiated_once
    # register it twice
    PluginManager.register_plugin CallRecorderPlugin
    PluginManager.register_plugin CallRecorderPlugin
    pm = PluginManager.new(nil,nil,nil)
    assert_equal 1, CallRecorderPlugin.count[:startup], 'should only instantiate once'
  end
  
  # test that method naming is determined correctly for commands, since
  # they're the ones that are being called during dispatch
  def test_method_naming
    pm = get_new_pm_with_callrecorder
    assert_equal 'privmsg', pm.method_for(CMD_PRIVMSG)
    assert_equal 'm001', pm.method_for(RPL_WELCOME)
    assert_equal 'm401', pm.method_for(ERR_NOSUCHNICK)
  end

  # test dispatch code

  def test_privmsg_dispatch
    assert_dispatch_for(@private_privmsg, CMD_PRIVMSG)
  end
  
  def test_servermsg_dispatch
    assert_dispatch_for(@general_server_message, RPL_WELCOME)
  end
  
  def test_catchall_dispatch
    pm = get_new_pm_with_callrecorder
    pm.dispatch(@unknown_message)
    assert_equal 1, pm.threads.size # make sure thread finished
    assert_equal 1, CallRecorderPlugin.count[:catchall]
  end
  
  def test_nasty_plugin_dispatch
    pm = get_new_pm_with_nasty
    pm.dispatch(@private_privmsg) # the dispatch will throw an exception
    assert_equal 1, pm.threads.size
    sleep(PluginManager::THREAD_READY_WAIT * 2 )
    # phantom error happening here if the thread doesn't finish fast enough - needed to wait longer
    assert_equal 0, pm.threads.size # if it got this far without exceptions, it's ok
  end
  
  def test_nasty_plugin_dispatch_incorrect_args
    pm = get_new_pm_with_nasty
    pm.dispatch @unknown_message
  end
  
  # if anything is registered for m123 (which One is) then the new dispatch code (revision 60something)
  # didn't call catchall on any other plugins. this tests for that, to make sure it's fixed.
  def test_proper_dispatch_handling
    PluginManager.register_plugin DuplicatePluginOne # handles m123
    PluginManager.register_plugin DuplicatePluginTwo
    pm = PluginManager.new nil, nil, nil
    pm.dispatch @unknown_message # m123, only One handles this, Two doesn't
    # call recorder uses CallRecorderPlugin class var to record, using that:
    assert_equal 1, CallRecorderPlugin.count[:m123]
    assert_equal 1, CallRecorderPlugin.count[:catchall], 'catchall should have been invoked'
    # now, make sure catchall gets called twice for another unknown:
    pm.dispatch @unknown_message_two # m124, neither handles this
    assert_equal 3, CallRecorderPlugin.count[:catchall], 'catchall should have been invoked twice more'
  end
  
  # cleanup/teardown
  
  def test_thread_cleanup
    pm = get_new_pm_with_callrecorder
    assert_equal 0, pm.threads.size
    pm.dispatch(@general_server_message)
    assert_equal 1, pm.threads.size
    # thread will be sleeping, so kill it and then wait for the cleanup
    pm.threads.first.kill
    sleep(PluginManager::THREAD_READY_WAIT * 2) # wait for thread cleanup
    assert_equal 0, pm.threads.size # should be empty again
  end
  
  def test_teardown
    pm = get_new_pm_with_callrecorder
    assert pm.janitor # should be a janitor thread running
    assert_equal 1, CallRecorderPlugin.count[:startup]
    assert_equal nil, CallRecorderPlugin.count[:teardown]
    assert_equal 1, pm.plugins.size
    pm.teardown
    assert_equal 1, CallRecorderPlugin.count[:teardown]
    assert_equal 0, pm.plugins.size
  end
  
  # make sure no dispatches go out while teardown is happening
  # do this by invoking teardown on a plugin that sleeps during teardown
  def test_teardown_is_exclusive
    pm = get_new_pm_with_nasty
    assert_equal 0, pm.threads.size
    t = Thread.new { pm.teardown }
    # make sure teardown runs first! this was causing phantom failures when the dispatch
    # call was being executed before the teardown call
    t.join(0.1)
    pm.dispatch(@general_server_message) # waits, but shouldn't ever execute if teardown is successful
    assert_equal 0, pm.threads.size # nothing should have been dispatched!
    t.join # finish up
  end
  
  def test_load_plugins_from_dir
    pm = PluginManager.new(nil,{:plugin_dir=>'test/fixtures'},nil)
    # only the test plugin should be registered for RPL_TOPIC
    assert_equal 1, pm.plugins.size, 'TestPlugin should have been registered'
    assert_equal TestPlugin, pm.plugins.first.class
  end
  
  def test_load_plugins_from_invalid_dir
    assert_raise(Errno::ENOENT) do
      pm = PluginManager.new(nil,{:plugin_dir=>'invalid_directory'},nil)
    end
  end
  
  ##### helpers
  
  def get_new_pm_with_callrecorder
    PluginManager.register_plugin CallRecorderPlugin
    PluginManager.new(nil,nil,nil) # returns
  end
  
  def get_new_pm_with_nasty
    PluginManager.register_plugin NastyPlugin
    PluginManager.new(nil,nil,nil)
  end

  # helper for dispatch testing
  def assert_dispatch_for(message,command)
    PluginManager.register_plugin CallRecorderPlugin
    pm = PluginManager.new(nil,nil,nil)
    assert_equal nil, CallRecorderPlugin.count[command]
    pm.dispatch(message)
    assert_equal 1, pm.threads.size # make sure thread finishes
    # sleep(PluginManager::THREAD_READY_WAIT) # add this if dispatch stops working on slow systems
    assert_equal 1, CallRecorderPlugin.count[command]
  end
  
end