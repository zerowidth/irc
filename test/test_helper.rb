require 'test/unit'
require 'logger'
$:.unshift File.expand_path(File.dirname(__FILE__) + "/../lib")
$:.unshift File.dirname(__FILE__) # for including mocks (require 'mocks/somemock')

require 'rubygems'
require 'active_support/core_ext/kernel/reporting' # for silence_warnings

# require 'irc' # load up the irc libraries
require 'notification'
require 'irc/connection'
require 'irc/plugin'
require 'irc/plugin_manager'
require 'irc/client'
require 'irc/message'
require 'irc/event'

require 'stubs/socket_stub'

# expose the guts of stuff, makes testing workable
module IRC
  
  class Client
   attr_accessor :config, :state
   attr_reader :plugins, :connection # make the basics accessible
  end
  
  class PluginManager
    def self.plugins; @@plugins || []; end
    def self.reset_plugins; @@plugins = []; end # for testing registration code
    attr_reader :plugins
  end

  class Connection
    attr_reader :connection_thread, :socket
    
    class TCPSocket < SocketStub; end # force connection to use a stub!

    def set_disconnect
      @disconnect = true
    end
  end

end

# allow access to observers
module Notification
  attr_reader :janitor_thread, :observers, :notify_threads
end

# add some callback-related assertions
module Test::Unit::Assertions

  def assert_false boolean, msg = nil
    assert_equal false, boolean, msg
  end
  
  # callback assertions and helper class
  class CallbackRecorder
    attr_reader :calls
    def initialize(*callbacks)
      @calls = []
      callbacks.each do |callback|
        callback = callback.first if callback.is_a? Array
        self.class.send :define_method, callback.to_sym do |*args|
          if args.size > 0
            @calls << [callback.to_sym, *args]
          else
            @calls << callback.to_sym
          end
        end # define method
      end # each
    end # def
  end # class
  
  # callbacks can be a list of strings or arrays with [:callback, arg1, arg2]
  def assert_callbacks(object, *callbacks, &blk)
    recorder = CallbackRecorder.new(*callbacks)
    callbacks.each do |callback|
      callback = callback.first if callback.is_a? Array
      object.add_observer recorder, callback
    end
    yield
    wait_for_callback_dispatch object
    assert_equal callbacks, recorder.calls, "callbacks did not match"
  end
  
  alias_method :assert_callback, :assert_callbacks
  
  def assert_callbacks_include(object, *callbacks, &blk)
    recorder = CallbackRecorder.new(*callbacks)
    callbacks.each do |callback|
      callback = callback.first if callback.is_a?(Array) && callback.size > 1
      object.add_observer recorder, callback
    end
    yield
    wait_for_callback_dispatch object
    callbacks.each do |callback|
      assert_equal callback, recorder.calls.detect {|cb| cb == callback}, "expected callback " + [callback].flatten.first.to_s
    end
  end

  def assert_observing(observer, observed, *callbacks)
    callbacks.each do |callback|
      assert observed.observers, "no observers are watching #{observed.class}"
      assert observed.observers[callback], "no observers are watching #{observed.class} for callback :#{callback}"
      assert observed.observers[callback].include?(observer), 
        "#{observer.class} should be observing #{observed.class} for callback :#{callback}"
    end
  end
  
end

class Test::Unit::TestCase
  def wait_for_callback_dispatch(obj) # wait for asynchronous callbacks to return
    obj.janitor_thread.join if obj.janitor_thread
  end
end

def each_irc_class
  [IRC::Client, IRC::Connection, IRC::Message, IRC::Plugin, IRC::PluginManager ].each do |base|
    yield base
  end
end

# silence all the logging except for fatal errors
logger = Logger.new(STDERR)
logger.level = Logger::FATAL
each_irc_class do |baseclass|
  baseclass.logger = logger
end

# now that socket is a stub, this isn't really required... 
TEST_HOST = 'localhost'
TEST_PORT = 12345