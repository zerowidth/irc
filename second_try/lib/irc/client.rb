# system includes
require 'monitor' # used for socket synchronization
require 'socket'

# irc includes
require 'irc/config'
require 'irc/plugin_handler'

module IRC
  
  LOGGING = false
  
  # raise this exception if Client#start is called more than once per instance
  class ClientAlreadyRunning < Exception; end;
  
  class Client

    # networking config
    # seconds to wait for data on the socket before spinning back around
    SOCKET_READY_WAIT = nil# nil says "wait forever", i don't need to loop right now 0.1 

    attr :config
    attr :channels

    def initialize
      @config = Config.new
      @socket = nil
      
      # plugin handler (initialized during #start)
      @plugins = nil
      
      # flags
      @running = false # global flag
      @quit = nil # quit flag used for main loop
      
      # state
      @channels = {} # key is chan, val is topic (set by core plugin)
      
    end
    
    # configuration changes, including config.load_from_file, assumed
    # between Client.new and #start since some are required...
    
    def start
      # make sure we're not already running
      raise ClientAlreadyRunning if @running
      @running = true
      
      # set up the plugins 
      @plugins = PluginHandler.instance
      #@plugins.load_plugins(@config[:plugin_dir])
      @plugins.load_plugin('irc/core_plugin.rb')

      # raise exception unless the config's got all the required params
      log "client starting"
      @config.exception_unless_configured
      mainloop()
      
    end

    # tells client thread to stop, does cleanup
    def shutdown
      @quit = true
      @plugins.shutdown
      @plugins = nil
      @running = false
    end
    
    # ----- # bot control commands, use while bot is running
    # include a .running? flag or method? maybe. but not now.
    
    def send_raw(raw_message)
      if @socket && !@socket.closed?
        @socket.synchronize do
          log "<-- #{raw_message.inspect}"
          @socket.puts(raw_message)
        end
      else
        log "socket closed, can't send #{raw_message}"
      end
    end
    
    def privmsg(who,message)
      send_raw("PRIVMSG #{who} :#{message}")
    end
    
    def nick(newnick)
      log "attempting to change nick to #{newnick}"
      send_raw("NICK #{newnick}")
      @config[:oldnick] = @config[:nick]
      @config[:nick] = newnick # won't be returned until oldnick is nil
      # core plugin handles nick collisions and
      # sets config to new nick on success (by deleting config[:oldnick])
      # success is either RPL_WELCOME or CMD_NICK
    end

    def join(channel)
      send_raw("JOIN #{channel}")
      # core plugin handles success & topic
    end
    
    def part(channel, reason=nil)
      reason ? send_raw("PART #{channel} :#{reason}") : send_raw("PART #{channel}")
      @channels.delete(channel)
    end
    
    def quit(reason='client quit')
      send_raw("QUIT :#{reason}")
      @quit = true
    end
    
    private # ----- # ----- #
    
    # main bot loop
    def mainloop
      @quit = false # reset here in case bot is restarted
      while !@quit do
        begin
          log "attempting connection"
          connect()
          catch(:disconnected) do
            while !@quit do
              # returns true if socket changed (either data or closed)
              if Kernel.select([@socket], nil, nil, SOCKET_READY_WAIT) && !@quit
                data = @socket.gets # data is nil if socket is closed
                throw :disconnected unless data
                data.strip! # clear out whitespace, crlf
                if data.length > 0
                  log "--> #{data.inspect}"
                  process_data(data)
                end
              end
            end
          end # catch :disconnected
        rescue SystemCallError => e # socket exceptions -- network errors
          log "connection error: #{e}, retrying in #{@config.retry_wait} seconds"
          sleep(@config.retry_wait)
          retry unless @quit # back to the top!
        ensure
          @socket.close if @socket && !@socket.closed?
        end

        unless @quit
          log "disconnected, reconnecting in #{@config[:retry_wait]} seconds"
          sleep(@config[:retry_wait])
        end

      end
      log "client exited"
    end
    
    # connect to the server
    def connect
      @socket = TCPSocket.open(@config[:host], @config[:port])
      @socket.extend(MonitorMixin) # enable synchronization on the socket
      log "connected to #{@config[:host]} on #{@config[:port]}"
      register()
    end
    
    # main data handler
    def process_data(data)
      msg = Message.new(self,data)
      #log "dispatching: #{data}"
      @plugins.dispatch_message(msg)
    end
    
    # ----- # internal irc commands
    
    def register
      log "registering with server"
      # ENHANCEMENT: add connection password (PASS command)... sometime.
      send_raw("USER #{@config[:user]} 0 * :#{@config[:realname]}")
      send_raw("NICK #{@config[:nick]}")
      # core plugin will handle nick errors
    end
    
    # ----- # utilities
    
    # TODO replace me with Logger or something, eventually
    def log(str)
      puts str if LOGGING
    end
    
  end
  
end