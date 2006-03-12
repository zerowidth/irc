class Client
  def go
    puts "went"
  end
end

class Message
  def initialize(client)
    @client = client
  end
  def go
    @client.go
  end
end

class Handler
  attr :t
  def initialize
    @t = nil
  end
  def go(message)
    @t = Thread.new do
      message.go
    end
  end
  def done
    @t.join if @t
  end
end

c = Client.new
m = Message.new(c)
h = Handler.new
p h.t
h.go(m)
p h.t
h.t.join
