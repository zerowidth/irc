# February 26, 2006, 9:30pm
# ok, this funky stuff is so i can learn how the Singleton module works its magic, 
# ... and break it :D

# test some basic module stuff
module Mod
  def hi
    puts "hello!"
  end
end
class Erk
  include Mod
end
Erk.new.hi

puts '***'

# FIRST TRY
# need to override the PluginHandler and Plugin singleton code
# so all tests are decoupled from each other!

# ok, so this breaks the registration code: PluginHandler is instantiated during
# the test setup, and then each time register_plugin is called, since .instance is 
# called again...

#module IRC
#  class PluginHandler
#    public_class_method :new
#    def self.instance; self.new; end
#  end
#  
#  class Plugin
#    public_class_method :new
#    def self.instance; self.new; end
#  end
#end

# totally doesn't work. ok:

# NEXT TRY, this duplicates some of what happens in Singleton

module Test
  def lol
    puts 'lol'
  end
end
class << Test # override stuff in Test module
  def included(klass)
    puts "i was included in #{klass}"
    super
  end
end

class Foo
  include Test
end

# k, that learned me about the module callback

puts "***"

# see how introspective modules can be
module Introspect
  def self.modlook
    p Something.instance_methods
  end
end
class << Introspect
  module Something
    def one; end
    def two; end
  end
  
  def look
    p Something.instance_methods
  end
end

# Introspect.modlook # fails
Introspect.look

# ok, that tells me nothing, i don't even know why i did that... never mind.

puts "***"

=begin
Use the Source, Luke!

OK, here's the deal: Singleton is defined as a basic module, but then the 
singleton of Singleton (the class!) has methods added to it.
Inside this instance, a closure is defined that does all the funky-awesome
singleton-related code, which deals with @__instance__.
Also defined is included(), which is a callback defined in Module that
gets called whenever it's included somewhere. included() calls some code, including
a chunk of code to make .new private, and adds the Proc as a class method.
So... the trick is: override included() and add my own proc to allow destroy_singleton.

Oh tricksy tricksy... once it's instantiated, :instance is redefined to simply
return @__instance__ ... need to somehow get the proc back.

Aha, thanks to the way define_method works (it calls instance_eval with the supplied
block/proc), it works!
=end

require 'singleton' # get the code loaded

# and then add to it:
class << Singleton
  DestroyInstance = proc do
    @__instance__ = nil # this isn't enough by itself!
    class << self # define_method uses instance_eval, so self is SomeSingletonClass
      remove_method :instance # get rid of lame method
      define_method(:instance,FirstInstanceCall) # and put the old one back
    end
  end
  ShowInstance = proc do
    p @__instance__
  end
  
  alias :old_included :included
  def included(klass)
    old_included(klass)
    class << klass
      define_method(:destroy_instance,DestroyInstance)
      define_method(:show_instance,ShowInstance)
    end
  end
end

class Bar
  include Singleton
end

print "before: "
Bar.show_instance
puts "calling Bar.instance"
Bar.instance
print "after: "
Bar.show_instance
puts "destroying instance"
Bar.destroy_instance
print "after: "
Bar.show_instance
puts "calling instance"
Bar.instance
print "after second instance call: "
Bar.show_instance