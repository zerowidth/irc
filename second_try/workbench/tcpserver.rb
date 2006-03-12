require 'socket'
#require 'rubygems'
#require_gem 'flexmock'
#require 'flexmock'

class MockServer
  
  def initialize(port)
    # server settings 
    @server = nil
    @port = port
    @socket = nil # single-threaded server, one socket, period

    # server threads
    @server_thread = nil # main server loop
    @client_thread = nil # client connection handler

    # control flags
    @quit = false
    @disconnect = false
  end

  def start
    
    puts "start"
    
    @server = TCPServer.new(@port)
    
    @server_thread = Thread.new do
      @quit = false
      while !@quit # single-threaded server loop
        start_client_thread()
        @client_thread.join(0.1)
      end # server loop
      
      puts "quitting"
      
      # kill any current client (quitting now!)
      @client_thread.kill
      
      # cleanup on quit
      @socket.close unless !@socket || @socket.closed?
      @server.close unless !@server || @server.closed?
      
    end # server thread
    
  end
  
  # tell the server to drop whatever client it's got
  def disconnect
    @disconnect = true
  end
  
  def stop
    if @server_thread
      @quit = true
      @server_thread.join()
    end
    puts "server stopped"
  end
  
  private
  
  def start_client_thread
    return if @client_thread && @client_thread.alive?
    puts "starting client thread"
    
    @client_thread = Thread.new do
      @disconnect = false
      puts "---> waiting for connection"
      @socket = @server.accept
      puts "---> accepted connection"
      until @disconnect || @quit
        if Kernel.select([@socket], nil, nil, 0.5) # returns true if socket's changed
          data = @socket.gets
          break unless data # data is nil if connection's broken
          puts "data: #{data}"
        end
      end
      @socket.close
      puts "---> disconnected"
    end
    
  end

end

# tricky stuff: fast servers in succession, test cleanup code
puts '##### fast testing, checks that cleanup code is solid'

s = MockServer.new(12345)
s.start
s.stop

s = MockServer.new(12345)
s.start
s.stop

s = MockServer.new(12345)
s.start
s.stop

puts '####### ok, basic testing now:'

s = MockServer.new(12345)
s.start

c1 = TCPSocket.new('localhost',12345)
sleep(2)
c1.puts "client 1"
puts "closing c1"
c1.close

c2 = TCPSocket.new('localhost',12345)
c2.puts "client 2"

sleep(0.5)

puts "punting client 2"
s.disconnect

sleep(0.5)
puts "closing c2"
c2.close

# client without disconnect, just kill server
c3 = TCPSocket.new('localhost',12345)
c3.puts "client 3"

sleep(0.5)
puts "stopping"
s.stop

