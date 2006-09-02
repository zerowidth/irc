# from http://www.sitharus.com/articles/2006/02/06/and-then-the-train-hits-you
# and http://ruby-doc.org/stdlib/libdoc/observer/rdoc/index.html

# module Observable
#   def observe(event, object)
#     @observers ||= {}
#     @observers[event.to_sym] ||= []
#     @observers[event.to_sym] << object
#   end
#   
#   def notify(event, *args)
#     return unless @observers
#     event = event.to_sym
#     whom = []
#     whom += @observers[event] if @observers[event]
#     whom += @observers[:all] if @observers[:all]
#     whom.each do |obj|
#       obj.send(event, *args) if obj.respond_to? event
#     end
#   end
# end

class A
  include Notification
  def do_something
    notify :event
  end 
  def do_threaded
    threaded_notify :threaded
  end
end

class B
  def event(*args)
    puts "in event callback"
  end
  def threaded
    puts "in threaded callback"
  end
end

a = A.new
b = B.new
a.add_observer b, :all

a.do_something # => prints 'in event callback'
a.do_threaded # => prints 'in threaded callback'