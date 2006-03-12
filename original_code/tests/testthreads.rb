#!/usr/bin/env ruby -w

require 'threadmanager'


include IRC
class Foo
  def sup
    puts "sup"
  end
end
f = Foo.new
tm = ThreadManager.new(f)
tm.new_thread {sleep(5); f.sup; }

begin
  tm.check_threads
  puts 'tick'
  sleep(0.05)
end until tm.empty?
