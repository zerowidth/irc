require 'socket'
require 'rubygems' # be careful here! Config will collide if namespaces are weird
require 'flexmock'

class MockServer
  
  # logging turns on puts-to-console for basic mock server debugging
  # so you can tell what's going on in the mock server
  def initialize(port,logging=false)
    # server settings 
    @server = nil # tcp server socket/listener
    @port = port
    @socket = nil # single-threaded server, one socket for clients

    # server threads
    @server_thread = nil # main server loop
    @client_thread = nil # client connection handler

    # control flags
    @running = false
    @disconnect = false
    @logging = logging
    @running_mock = false # currently in a mock block (self#mock)
    
    # mock server
    setup_mock()

    log "mock server instantiated"
  end

  # start server
  # do this first, like in setup() in a test suite
  def start 
    log "starting mock server"
    @running = true
    @server = TCPServer.new(@port)
    
    @server_thread = Thread.new do
      # any exceptions in here are checked by MockServer#mock, which runs
      # the mock test and then joins this thread for a tiny fraction of a second
      # just in case any exceptions were raised
      while @running # single-threaded server loop
        start_client_thread()
        @client_thread.join(0.1) # check for disconnect or any exceptions
        # however: not all exceptions will be caught here for some reason... :/
        # that's ok though because start_client_thread() joins the thread too
        # just for a double-check
      end # server loop
      
      log "server thread closing"
      
      # kill any current client (quitting now!)
      @client_thread.kill
      
      # cleanup on quit
      log "closing sockets"
      @socket.close unless !@socket || @socket.closed?
      @server.close unless !@server || @server.closed?
      
    end # server thread
    
    #sleep 0.1 # wait for server to start

  end
  
  # tell the server to drop whatever client it's got right now
  # this is pretty much immediate and any pending socket sends will be canceled forthwith!
  # if you need to guarantee that data gets received by the server before disconnecting
  # a client, make sure you sleep for a bit (0.5 sec is fine) prior to calling this.
  def disconnect
    @disconnect = true
  end
  
  # kill the server. this means kill, not shutdown nicely.
  # i originally had a @quit control flag in the code but it's not all
  # that important to shutdown nicely when doing test cases, just kill the server
  # and move on with the testing
  def stop
    return unless @running
    @running = false
    @server_thread.join # server thread will shut itself down
  end

  # ok, this is the meat of MockServer.
  #
  # call it like this (assuming server is started)
  # @mockserver.mock do |mock|
  #   # use standard FlexMock mock calls here. return values get puts'd
  #   # to the server socket
  #   mock.should_receive(:data).with('somestring').and_return('another string').once
  #   # your test code here...
  # end
  # after the block is finished, the mock object is automatically verified
  # and server threads are checked for exceptions
  # 
  # please note that :data and :disconnect are pretty darn likely to be called,
  # so either define 'em or use mock.should_ignore_missing
  def mock(&block)
    raise ServerNotRunning unless @running
    raise AlreadyInMockBlock if @running_mock
    @running_mock = true
    yield @mock
    @mock.mock_verify
    # check for any exceptions raised in the server thread
    @server_thread.join(0.01)
    @running_mock = false
  end
  
  # reset the mock if necessary
  def reset_mock
    raise ResetMockInsideMockBlock if @running_mock # no funny business!
    setup_mock()
  end
  
  # tell the server to send some data. careful, #send() is a valid function
  # and it won't do what you think it does! (hint: doesn't send data)
  # this *might* need to be synchronized if things get too complex and if 
  # the socket traffic starts overwriting itself. but for now... it's fine!
  def send_data(str)
    if @socket && !@socket.closed?
      log "mock server sending data: #{str}"
      @socket.puts str
    end
  end
  
  private #############################
  
  def setup_mock
    @mock = FlexMock.new("Server Mock")
  end
  
  def start_client_thread
    return if @server.closed? || ( @client_thread && @client_thread.alive? )
    # ok, so we know the client thread is dead. rejoin it to make sure 
    # any exceptions that could have been thrown get caught by whomever!
#    @client_thread.join if @client_thread
    
    # ok, all clear. start up a new thread
    log "starting new server thread"
    @client_thread = Thread.new do
      @disconnect = false
      log "mock server waiting for connection"
      @socket = @server.accept unless @server.closed?
      log "mock server accepted connection"
      until @disconnect
        if Kernel.select([@socket], nil, nil, 0.05) # returns true if socket's changed
          begin
            data = @socket.gets
          rescue => e
            puts "exception: #{e}"
          end
          break unless data # data is nil if connection's broken
          data.strip! # clean up whitespace/newlines
          log "mock server received data: #{data}"
          ret = @mock.data(data) || nil
          send_data ret if ret
        end
      end # until
      @socket.close
      @mock.disconnect() # alert mock that we were forced to disconnect
      log "mock server disconnected client"
    end
    #log "server thread exiting"
  end
  
  def log(str)
    puts str if @logging
  end

  class ServerNotRunning < Exception; end
  class AlreadyInMockBlock < Exception; end
  class ResetMockInsideMockBlock < Exception; end;

end
