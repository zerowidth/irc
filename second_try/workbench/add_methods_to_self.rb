class Foo
  def add_method(sym)
    self.instance_eval %{
      def #{sym}(arg)
        puts arg
      end      
    }
  end
end

f = Foo.new
begin
  f.foo
rescue => e
  puts "rescued #{e}"
end

f.add_method(:foo)
f.foo('asdf')
f.add_method(:unf)
f.unf('lolz')

