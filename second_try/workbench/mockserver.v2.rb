require 'socket'
require 'rubygems' # be careful here! Config will collide if namespaces are weird
require 'flexmock'

class MockServer
  
  def initialize(port,logging=false)
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
    @logging = logging
    
    # mock server
    @mock = FlexMock.new("Server Mock")

  end

  # start server
  def start 
    log "starting mock server"
    @server = TCPServer.new(@port)
    
    @server_thread = Thread.new do
      @quit = false
      while !@quit # single-threaded server loop
        start_client_thread()
        @client_thread.join(0.1)
      end # server loop
      
      log "quitting"
      
      # kill any current client (quitting now!)
      @client_thread.kill
      
      # cleanup on quit
      @socket.close unless !@socket || @socket.closed?
      @server.close unless !@server || @server.closed?
      
    end # server thread
    
    @server_thread = Thread.new do
      @quit = false
      while !@quit # single-threaded server loop
        
      end # server loop
    end # server thread
    
  end
  
  # tell the server to drop whatever client it's got right now
  # this is pretty much immediate and any pending socket sends will be canceled forthwith!
  # if you need to guarantee that data gets to the server before disconnecting
  # a client, make sure you sleep for a bit (0.5 sec is fine) prior to calling this.
  def disconnect
    @disconnect = true
  end
  
  # kill the server
  def stop
    if @server_thread
      @quit = true
      @server_thread.kill if @server_thread.alive?
      @socket.close unless !@socket || @socket.closed?
      @server.close unless !@server || @server.closed?
    end
    log "mock server stopped"
  end

  # call it like this, for example:
  # @mockserver.mock do |mock|
  #   mock.should_receive(:data).with('somestring').and_return('another string').once
  #   # your test code here
  # end
  # 
  # please note that :data and :disconnect are pretty darn likely to be called,
  # so either define 'em or use mock.should_ignore_missing
  def mock(&block)
    yield @mock
    @mock.mock_verify
  end
  
  # tell the server to send some data. careful, #send() is a valid function
  # and it won't do what you think it does!
  # this *might* need to be synchronized if things get too complex and if 
  # the socket traffic starts overwriting itself. but for now... it's fine!
  def send_data(str)
    @socket.puts str if @socket && !@socket.closed?
  end
  
  private #############################
  
  def start_client_thread
    return if @client_thread && @client_thread.alive?
    @client_thread = Thread.new do
      @disconnect = false
      log "mock server waiting for connection"
      @socket = @server.accept
      log "mock server accepted connection"
      until @disconnect || @quit
        if Kernel.select([@socket], nil, nil, 0.05) # returns true if socket's changed
          data = @socket.gets
          break unless data # data is nil if connection's broken
          data.strip! # clean up whitespace/newlines
          log "mock server received data: #{data}"
          ret = @mock.data(data)
          send_data ret if ret
        end
      end
      @socket.close
      @mock.disconnect
      log "mock server disconnected client"
    end
    
  end
  
  def log(str)
    puts str if @logging
  end

end
