$LOAD_PATH.unshift( File.join(File.dirname(__FILE__),'../lib') );
require 'rubygems'
require 'eventmachine'
require 'xmpp4r-simple'
require 'active_support'
require 'syslog'

require 'workhorse/config'
require 'workhorse/actions'

module Workhorse
  mattr_accessor :im, :interrupted
  @@interrupted = false
  
  def self.run
    # Connect to IM server
    begin
      @@im = Jabber::Simple.new("#{WH::Config.im.jid}/#{WH::Config.im.resource}", "#{WH::Config.im.password}", :chat, "Workhorse available")
      self.log("Connected as #{WH::Config.im.jid}")
    rescue Jabber::ClientAuthenticationFailure
      self.log("Authentication failed for #{WH::Config.im.jid}")
      exit
    end
    
    # Begin waiting for messages
    EM.run do
      EM::PeriodicTimer.new(1) do
        
        # Stop if we get an interrupt
        if @@interrupted
          EM.stop
        end
        
        # Check if we got disconnected
        unless @@im.connected?
          self.log("Disconnected from IM server")
          @@im.reconnect
        end
        
         WH::Actions.run
         
      end
    end
  end
  
  def self.terminate
    self.log("Disconnected from IM server")
    @@im.status(:away, 'Workhorse unavailable')
  end
  
  def self.log(message,type="debug")
    Syslog.open('workhorse', Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.method(type).call message }
  end
end

WH = Workhorse