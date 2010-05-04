require 'rubygems'
require 'eventmachine'
require 'active_support'
require 'syslog'

require 'xmpp4r'
require 'xmpp4r/muc/helper/mucclient'
include Jabber

require 'workhorse/config'
require 'workhorse/actions'

module Workhorse
  mattr_accessor :im, :interrupted
  @@interrupted = false
  
  def self.run
    self.connect
    
    # Begin waiting for messages
    EM.run do    
      EM::PeriodicTimer.new(1) do    
        # Stop if we get an interrupt
        if @@interrupted
          EM.stop
        end
        
        # Check if we got disconnected
        if @@im.is_disconnected?
          self.log("Disconnected from IM server", "warning")
          sleep 5
          self.connect
        end
      end
    end
  end
  
  def self.connect
     # Connect to IM server
    begin
      @@im = Client.new(JID::new("#{WH::Config.im.jid}/#{WH::Config.im.resource}"))
      @@im.connect
      @@im.auth("#{WH::Config.im.password}")
      @@im.send(Jabber::Presence.new(nil, "Workhorse available", 1))
      self.log("Connected as #{WH::Config.im.jid}")
      
      WH::Actions.run
      
      WH::Config.im.channels.to_hash().each do |cn,ca|
        muc = Jabber::MUC::MUCClient.new(@@im)
        WH::Actions.run_muc(cn,muc)
        muc.join("#{cn}/#{ca[:nick]}", ca[:password])
      end
    rescue Jabber::ClientAuthenticationFailure
      self.log("Authentication failed for #{WH::Config.im.jid}","warning")
      exit
    end
  end
  
  def self.terminate
    self.log("Disconnected from IM server","warning")
    @@im.send(Jabber::Presence.new.set_show(:xa).set_status('Workhorse unavailable'))
  end
  
  def self.reply(m, message="Dunno how to #{m.body}")
    r = Message.new(m.from, message)
    r.type = m.type
    @@im.send(r)
  end
  
  def self.reply_muc(muc, m, message="Dunno how to #{m.body}")
    r = Message.new(nil, message)
    r.type = m.type
    muc.send(r)
  end
  
  def self.log(message,type="debug")
    Syslog.open('workhorse', Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.method(type).call message }
  end
  
  def self.clean_jid(jid)
    jid = Jabber::JID.new(jid)
    return jid.strip.to_s
  end
end

WH = Workhorse