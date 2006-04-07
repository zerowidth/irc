# IRCConnection is the socket/network code handler class.
# This will handle reconnects, receiving data from the socket, sending data
# to the socket, etc.

# To use IRCConnection, instantiate it with the host and port, and then
# call start. This will begin the internal data processing thread that
# connects to the server, receives data, and handles reconnects

require 'socket'
require 'irc/client_commands' # need DataCommand
require 'irc/cattr_accessor'

module IRC
  
class IRCConnection
  
  SOCKET_READY_WAIT = nil # polling wait time for socket, set to nil for infinite
  
  cattr_accessor :logger
  
  def initialize(host, port, command_queue, retry_wait=10)
    @host = host
    @port = port
    @command_queue = command_queue # queue to send data to
    # configurable via params to ease testing:
    @retry_wait = retry_wait # how long to wait before trying a connection again
    @socket = nil
    @connection_thread = nil
    @disconnect = false # flag for connection thread loops
  end
  
  def start
    # connect is called within the main loop, but it's called here as well
    # to gather any network errors or other exceptions that might occur
    connect
    # start main loop
    start_main_loop
  end
  
  # disconnect will close down a current connection
  def disconnect
    @disconnect = true; # set the flag
    @socket.close unless @socket.closed? # then kill the connection
    # now join the thread - catch exceptions, and close it all down
    @connection_thread.join if @connection_thread
    @connection_thread = nil
  end
  
  # send data to the socket
  def send(data)
    raise "not connected" unless connected?
    logger.info "<-- " + data.inspect
    @socket.puts data
  end
  
  def connected?
    @socket && !@socket.closed?
  end
  
  # interrupts the current connection, leaving the reconnect loop running
  def cancel_current_connection
    @socket.close
  end
  
  private #############################
  
  def connect
    raise "already connected" if connected?
    @socket = TCPSocket.open(@host, @port)
  end
  
  def start_main_loop
    @disconnect = false
    @connection_thread = Thread.new do
      socket_main_loop
    end # thread
    @connection_thread.join(0.01) # check for uncaught exceptions during startup
  end
  
  def socket_main_loop
    until @disconnect do
      begin
        # connect (unless already connected, which is the case if #start is called)
        connect unless connected?
      
        # loop on the socket, catch a disconnection event
        # two ways things could go:
        #   one: server disconnects us, gets returns nil.
        #   two: we disconnect. gets throws exception.
        #   three: ok three ways: some other random error
        until @disconnect do
          # wait for state change on the socket
          if Kernel.select([@socket], nil, nil, SOCKET_READY_WAIT)
            data = @socket.gets # gets throws an IOError if the socket is closed
            break unless data # data is nil if server disconnected us
            data.strip! # clear out whitespace, crlf
            if data.length > 0 # ignore if it was just whitespace
              handle_data(data)
            end
          end
        end # loop
      
        # wait for the reconnect
        sleep_for_retry

      rescue SystemCallError, IOError => e # socket exceptions or network errors
        unless @disconnect
          logger.warn "connection error: #{e}, retrying in #{@retry_wait} seconds"
          sleep_for_retry
        end
      ensure
        @socket.close if connected?
      end
    end # until @disconnect
  end
  
  def sleep_for_retry
    sleep(@retry_wait) unless @disconnect
  end

  def handle_data(data)
    logger.info "--> " + data.inspect
    @command_queue.add(DataCommand.new(data))
  end
  
end
  
end # module