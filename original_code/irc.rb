# system includes
require 'socket'
require 'monitor' # used for socket synchronization

# bot includes
require 'config' # handles config
require 'rfc2812' # valid responses (RPL_WELCOME etc), CMD_PRIVMSG, etc. commands, parsing regexes
require 'plugins' # handles plugins
require 'message' # message object
require 'message_parsing' # message parsing
require 'threadmanager' # handles threads

module IRC
  
  # in seconds, how long the main loop waits for new data on the socket
  # before handling anything else (event queues, thread lists)
  SOCKET_READY_WAIT = 0.1
  
  class Client
    
    include MonitorMixin # socket synchronization
    
    attr_reader :config
    attr_reader :threads
    
    def initialize(config_file=nil)
      @config = Config.new
      @socket = nil
      @plugins = Plugins.new(@config.plugin_dir, self)
      @plugins.load_plugins
      @quit = false
      @threads = ThreadManager.new
    end
    
    ##### main loop
    
    def mainloop
      @quit = false
      loop do
        begin
          connect
          loop do
            check_data # check socket for new data
            @threads.check_threads # check to see if any threads are done
          end # inner data read loop
          @socket.close
          if @quit
            break
          else
            puts "disconnected, reconnecting in #{@config.retry_wait} seconds"
            sleep(@config.retry_wait)
          end
        rescue SystemCallError => e
          puts "connection error #{e}, retrying in #{@config.retry_wait} seconds"
          sleep(@config.retry_wait)
          retry unless @quit
        ensure
          @socket.close if @socket && !@socket.closed?
        end
      end # outer reconnect loop
      
      @threads.kill_all
      
      puts "all cleaned up. ending main loop."
    end
    
    ##### 
    
    def send_raw(raw_message)
      @socket.synchronize do
        puts "sending raw message #{raw_message}"
        @socket.puts(raw_message)
      end
    end

    def send_message(message_type, *params)
      
    end
    
    def set_new_nick(newnick)
      @config.set_nick(newnick)
      register()
    end
    
    def reload_plugins
      @plugins.reload_plugins
    end
    
    def quit(reason)
      reason ||= 'goodbye'
      send_raw("QUIT :#{reason}")
      puts "quitting..."
      @quit = true
    end
    
    private
    
    # called by main loop
    def check_data 
      ready = Kernel.select([@socket], nil, nil, SOCKET_READY_WAIT)
      if ready
        data = @socket.gets
        break if @socket.closed? || !data || @quit
        data.strip! # clear out whitespace, crlf
        if data.length > 0
print "--> "; p data
          process_data(data)
        end
      end
    end
    
    def connect
      @socket = TCPSocket.open(@config.host, @config.port)
      @socket.extend(MonitorMixin) # enable synchronization on the socket
puts "connected to #{@config.host} on #{@config.port}"
      register()
    end
    
    def register
      send_raw("NICK #{@config.nick}")
      send_raw("USER #{@config.user} 0 * :#{@config.realname}")
      send_raw("OPER #{@config.operuser} #{config.operpass}") if @config.operuser &&  @config.operpass
      send_raw("MODE #{@config.nick} +F") # flood-protect
      autojoin()
    end
    
    def autojoin
      @config.autojoin.each do |chan|
        send_raw("JOIN #{chan}")
      end if @config.autojoin
    end

    def process_data(data)
      message = Message.new(self,data)
      @plugins.dispatch(message)
    end

  end # class 
end # module
