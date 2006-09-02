# IRCConnection is the socket/network code handler class.
# This will handle reconnects, receiving data from the socket, sending data
# to the socket, etc.

# To use IRCConnection, instantiate it with the host and port, and then
# call start. This will begin the internal data processing thread that
# connects to the server, receives data, and handles reconnects

require 'socket'
require 'notification'
require 'irc/common'
#require 'irc/client_commands' # need DataCommand & notifications

module IRC
  
class Connection
  include Notification
  
  SOCKET_READY_WAIT = nil # polling wait time for socket, set to nil for infinite
  
  cattr_accessor :logger

  def initialize(host, port)
    @host = host
    @port = port
    
    @socket = nil
    @connection_thread = nil
    @disconnect = false # flag for connection thread loops
  end

  def connect
    # start_connection is called within the main loop, but it's called here as well
    # to gather any network errors or other exceptions that might occur
    start_connection
    start_main_loop if connected?
  end
  
  # disconnect will close down a current connection
  def disconnect
    @disconnect = true; # set the flag
    @socket.close if @socket && !@socket.closed? # kill the connection
    # now join the thread - catch exceptions, and close it all down
    @connection_thread.join if @connection_thread
    @connection_thread = nil
    # notify :disconnected # this will happen when the socket main loop ends
  end
  
  def wait_for_disconnect
    @connection_thread.join if @connection_thread
  end
  
  # send data to the socket
  # ignores network errors when sending
  def send(data)
    begin
      raise "not connected" unless connected?
      logger.info "<-- " + data.inspect
      @socket.puts data
    rescue RuntimeError, SystemCallError, IOError => e # socket exceptions or network errors
      logger.warn "connection error: #{e}"
      notify :connection_error, e
    end
  end
  
  def connected?
    !@socket.nil? && !@socket.closed?
  end
  
  private #############################
  
  def start_connection
    raise "already connected" if connected?
    logger.info "connecting to #{@host}:#{@port}"
    begin
      @socket = TCPSocket.open(@host, @port)
      notify :connected
    rescue Errno::ECONNREFUSED => e
      notify :connection_error, e
    end
  end
  
  def start_main_loop
    @disconnect = false
    @connection_thread = Thread.new do
      socket_main_loop
    end
    @connection_thread.join(0) # check for uncaught exceptions during startup
  end
  
  def socket_main_loop
    begin
      # connect (unless already connected, which is the case if #start is called)
      start_connection unless connected?

      # loop on the socket
      # the ways things could go:
      #   one: server disconnects us, gets returns nil.
      #   two: we disconnect. gets throws exception.
      #   three: ok three ways: some other random error
      #   four: @disconnect flag is set (externally) by a test
      until @disconnect do
        data = @socket.gets # gets throws an IOError if the socket is closed
        break unless data # data is nil if server disconnected us!
        data.strip! # clear out whitespace, crlf
        if data.length > 0 # ignore if it was just whitespace
          handle_data(data)
        end
      end

    rescue SystemCallError, IOError => e # socket exceptions or network errors
      unless @disconnect
        logger.warn "connection error: #{e}"
        notify :connection_error, e
      end
    ensure
      @socket.close if connected?
    end

    notify :disconnected
  end

  def handle_data(data)
    logger.info "--> " + data.inspect
    notify :data, data
  end
  
end
  
end # module