# this tests the whole shebang, pretty much.
# can't just test Client all by itself, since it pulls in so many dependencies
# including plugin handlers, etc. etc. etc. so without replacing half the code with my
# own modules or something, treat this as a functional test rather than a unit test

require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'mocks/mockserver'
require 'irc/client'
include IRC
class TestClient < Test::Unit::TestCase
  
  def setup
    PluginHandler.destroy_instance # fresh and clean!
    @client = Client.new
    @client.config[:host] = 'localhost'
    @client.config[:port] = 12345
    @client.config[:retry_wait] = 1 # second to retry connection
    @client.config[:nick] = 'rbot' # may as well be explicit (this is a default)
    #@client.config[:plugin_dir] = File.expand_path(File.dirname(__FILE__) + "/../../plugins")
    @server = MockServer.new(12345,false) # port 12345
    @server.start()
  end

  def teardown
    @server.stop # don't forget!
    @server = nil
    @client.shutdown # this is critical! garbage collection isn't immediate or guaranteed!
    @client = nil; 
  end
  
  def test_start_client_twice
    @server.mock { |mock| mock.should_receive(:data) }
    s = Thread.new { @client.start() }
    t = Thread.new { @client.start() } # should raise an exception
    assert_raise(ClientAlreadyRunning) {
      t.join(0.01) # join this, instead of just calling, in case the exception isn't raised
    }
  end
  
  def test_connect_and_quit
    @server.mock do |mock|
      mock.should_receive(:data).with('USER rbot 0 * :ruby irc bot').ordered.once
      mock.should_receive(:data).with("NICK rbot").ordered.once
      mock.should_receive(:data).with('QUIT :done').
        and_return{@server.disconnect; nil}.ordered.once
      mock.should_receive(:disconnect).ordered.once

      t = Thread.new { @client.start }; 
      sleep(0.5) # wait for connect
      @client.quit('done');
      sleep(0.5) # wait for disconnect
    end
  end
  
  def test_reconnect
    # gotta break this into two sections cuz flexmock's ordering doesn't quite cut it
    clientthread = nil # client thread
    @server.mock do |mock|
      mock.should_receive(:data).with('USER rbot 0 * :ruby irc bot').once.ordered
      mock.should_receive(:data).with("NICK rbot").once.\
        and_return { @server.disconnect; nil}.ordered
      mock.should_receive(:disconnect).once.ordered

      clientthread = Thread.new { @client.start }
      sleep(1) # wait for connect and server disconnect 
    end
    @server.reset_mock # resetting mock required sequence

    @server.mock do |mock|
      mock.should_receive(:data).with('USER rbot 0 * :ruby irc bot').once.ordered
      mock.should_receive(:data).with("NICK rbot").once.ordered
      mock.should_receive(:data).with('QUIT :done').\
        and_return { @server.disconnect; nil}.once.ordered
      mock.should_receive(:disconnect).ordered
      sleep 2 # wait for reconnect to happen
      @client.quit('done')
      sleep 0.5
    end
  end
  
  ##### test basic commands #####
  
  def test_join_command
    @server.mock do |mock|
      mock.should_receive(:data)
      mock.should_receive(:data).with('JOIN #test').once.\
        and_return(':rbot@rbot.rbot JOIN #test')
      t = Thread.new { @client.start }
      sleep 0.2
      @client.join('#test')
      sleep 0.5 # wait for join
      assert_equal '', @client.channels['#test'] # empty topic
      @server.send_data(':server.com 332 #test :topic here')
      sleep 0.2 # wait for dispatch & handling
      assert_equal 'topic here', @client.channels['#test']
    end
  end
  
  def test_part_command
    @server.mock do |mock|
      mock.should_receive(:data)
      mock.should_receive(:data).with('JOIN #test').and_return(':server JOIN #test')
      mock.should_receive(:data).with('PART #test :because').once
      t = Thread.new { @client.start }
      sleep 0.2
      @client.join('#test')
      sleep 0.2 # wait for join
      assert_equal '', @client.channels['#test'] # empty topic, not nil!
      @client.part('#test', 'because')
      sleep 0.2 # wait for dispatch & handling
      assert_nil @client.channels['#test']
    end
  end
  
  def test_nick_command
    @server.mock do |mock|
      mock.should_receive(:data)
      mock.should_receive(:data).with('NICK rbot2').\
        and_return(':rbot!rbot@rbot NICK rbot2').once
      t = Thread.new { @client.start }
      sleep(0.5) # wait for connect
      assert_equal 'rbot', @client.config[:nick]
      @client.nick('rbot2')
      sleep(1) # wait for plugin dispatch & handling

      # core plugin should change the config upon a successful nick change!
      # this relies on correct dispatching, etc.
      assert_equal 'rbot2', @client.config[:nick]
      assert_nil @client.config[:oldnick]
    end
  end
  
  def test_nick_collisions_during_register
    # tests that the nick collision plugin code is getting called, etc.
    # kinda duplicates the core plugin unit test, but this includes 
    # client and pluginhandler in the scope
    @server.mock do |mock|
      mock.should_receive(:data).once.ordered # USER
      mock.should_receive(:data).with("NICK rbot").\
        and_return(':server.com 433 rbot :Nickname is already in use').once.ordered
      mock.should_receive(:data).with("NICK rbot_").once.ordered#.\
        #and_return(':server.com 001 :welcome to the network')
      assert_equal 'rbot', @client.config[:nick]
      assert_nil @client.config[:oldnick]
      t = Thread.new { @client.start }
      sleep(1) # wait for nick collison handling
      assert_equal 'rbot', @client.config[:nick] # shouldn't be valid yet!
      # now tell the client that it's all good
      @server.send_data(':server.com 001 welcome, yo')
      sleep(1)
      assert_equal 'rbot_', @client.config[:nick]
      assert_nil @client.config[:oldnick]
    end
  end

end
