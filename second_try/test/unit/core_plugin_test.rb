require File.expand_path(File.dirname(__FILE__) + "/../test-helper")
require 'mocks/mockclient'
require 'mocks/mockmessage'
require 'irc/core_plugin.rb'
require 'irc/message'
include IRC

class TestCorePlugin < Test::Unit::TestCase
  
  def setup
    @plugin = CorePlugin.new
    @message = MockMessage.new
  end

  # server keepalive
  def test_ping
    @message.mock do
      # first param of a pong message is some number
      @message.should_receive(:[]).with(0).and_return('server.com').once # params[0]
      @message.should_receive(:reply_command).with(CMD_PONG, 'server.com').once
    
      @plugin.ping(@message)
    end
  end

  # join/topic
  
  def test_join
    @message.mock do
      @message.should_receive(:config).and_return(@message)
      @message.should_receive(:channels).and_return(@message)
      @message.should_receive(:[]).with(:nick).and_return('rbot')
      @message.should_receive(:[]).with(0).and_return('#test') # params[0]
      @message.should_receive(:[]=).with('#test','').once
      @plugin.join(@message)
    end
  end
  
  def test_someone_else_joins
    @message.mock do
      @message.should_receive(:config).and_return(@message)
      @message.should_receive(:channels).and_return(@message)
      @message.should_receive(:[]).with(:nick).and_return('rbot')
      @message.should_receive(:[]).with(0).and_return('#test') # params[0]
      @message.should_receive(:[]=).with('#test','').never
      @plugin.join(@message)
    end
  end
  
  def test_topic
    @message.mock do
      @message.should_receive(:channels).and_return(@message)
      @message.should_receive(:[]).with('#test').and_return('')
      @message.should_receive(:[]).with(0).and_return('#test') # params[0]
      @message.should_receive(:[]).with(1).and_return('some topic') # params[0]
      @message.should_receive(:[]=).with('#test','some topic').once
      @plugin.m332(@message)
    end
  end
  
  def test_topic_without_channel

  end

  # nick handling
  
  # most obvious nick change success is when server tells us our new nick
  def test_successful_nick_change
    @message.mock do
      @message.should_receive(:config).and_return(@message)
      # plugin needs to compare message.prefix[:nick] and message.params[0]
      @message.should_receive(:[]).with(:nick).and_return('rbot').twice # params and prefix
      @message.should_receive(:[]).with(0).and_return('rbot2').once # changing to rbot2
      # plugin should change client's config to validate that new nick is valid
      @message.should_receive(:[]=).with(:nick, 'rbot2')
      @message.should_receive(:[]=).with(:oldnick, nil).once

      @plugin.nick(@message)
    end
  end
  
  def test_successful_nick_during_registration
    @message.mock do
      @message.should_receive(:config).and_return(@message)
      @message.should_receive(:[]=).with(:oldnick, nil).once
      @plugin.m001(@message)
    end
    
  end
  
  # test: current nick was rbot, tried to change it to foo, so change it back
  def test_nick_in_use
    @message.mock do
      @message.should_receive(:config).and_return(@message)
      # plugin needs to see what we tried changing our nick to first
      @message.should_receive(:[]).with(:oldnick).and_return('rbot')
      # plugin will also ask for current nick value
      @message.should_receive(:[]).with(:nick).and_return('rbot')
    
      # put us back to where we were, and reset oldnick
      @message.should_receive(:[]=).with(:oldnick, nil).once
      @message.should_receive(:[]=).with(:nick, 'rbot').once
      @message.should_receive(:nick).never
    
      @plugin.m433(@message)
    end
  end
  
  # during some other time than registration? this shouldn't do anything
  def test_nick_with_empty_oldnick
    
  end
  
  # trying to connect as rbot, but it doesn't work. so try again with rbot_
  # :oldnick is nil since it's during registration
  def test_nick_in_use_during_registration 
    @message.mock do
      @message.should_receive(:config).and_return(@message)
      
      @message.should_receive(:[]).with(:oldnick).and_return(nil)
      @message.should_receive(:[]).with(:nick).and_return('rbot')
      
      # plugin should try to change our nick to something else
      @message.should_receive(:nick).with('rbot_')
      @plugin.m433(@message)
    end
  end

end
