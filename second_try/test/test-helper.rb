require 'test/unit'
$:.unshift File.expand_path(File.dirname(__FILE__) + "/../lib")
$:.unshift File.dirname(__FILE__) # for including mocks (require 'mocks/somemock')

# allow destruction of singleton instances (specifically: PluginHandler and Plugin)
# so tests of those things can work on fresh instances. hackahackahacka!

# load the singleton code...
require 'singleton'

# and break it!
class << Singleton
  DestroyInstance = proc do
    @__instance__ = nil # this isn't enough by itself!
    class << self # define_method uses instance_eval, so self is SomeSingletonClass
      remove_method :instance # get rid of the lame method
      define_method(:instance,FirstInstanceCall) # and put the old one back
    end
  end

  alias :old_included :included
  def included(klass)
    old_included(klass)
    class << klass
      define_method(:destroy_instance,DestroyInstance)
    end
  end
end

# load the irc files
require 'irc/client'
