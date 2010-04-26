$LOAD_PATH.unshift( File.join(File.dirname(__FILE__),'../lib') );
require 'rubygems'
require 'eventmachine'
require 'active_support'
require 'workhorse/worker'

module Workhorse
  module Actions
    include EM::Deferrable

    def self.run
      WH.im.add_message_callback do |m|
        if m.type != :error and m.body
          WH.log("Received message from #{m.from}: #{m.body}")
          case m.body
          when "test" :
            WH.reply(m,"You sent #{m.body}")
          when "lift" :
            EM.spawn do
              worker = Worker.new
              worker.callback {WH.reply(m, "Done lifting")}
              worker.heavy_lifting
            end.notify
            WH.log("Sending message to #{m.from}: Scheduled heavy job...")
            WH.reply(m, "Scheduled heavy job...")
          when "pull" :
            EM.spawn do
              worker = Worker.new
              worker.callback {WH.reply(m, "Done pulling")}
              worker.heavy_pulling
            end.notify
            WH.reply(m, "Scheduled heavy job...")
          else 
            if WH::Config.base.direct_default_response
              WH.reply(m,"Dunno how to #{m.body}")
            end
          end
        end
      end
    end
  
  def self.run_muc(cn=nil,muc=nil)
    unless cn and muc
      return
    end
    
    muc.add_message_callback do |m|
      fromus = "#{cn}/#{muc.nick}"
      if m.from != fromus and WH::Config.base.group_default_response
        WH.reply_muc(muc, m, "Dunno how to #{m.body}")
      end
    end

  end
  
  end
end