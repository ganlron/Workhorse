require 'rubygems'
require 'eventmachine'

module Workhorse
  module Actions
    class Worker
      include EM::Deferrable
      
      def heavy_lifting
        30.times do |i|
          puts "Lifted #{i}"
          sleep 0.1
        end
        set_deferred_status :succeeded
      end
  
      def heavy_pulling
        60.times do |i|
          puts "Pulled #{i}"
          sleep 0.1
        end
        set_deferred_status :succeeded
      end
    end
  end
end

# Register direct message handler
WH::Actions.handle('worker') {
  WH.im.add_message_callback do |m|
    if m.type != :error and m.body
      WH.log("Received message from #{m.from}: #{m.body}")
      case m.body
      when "test" :
        WH.reply(m,"You sent #{m.body}")
      when "ipath" :
        WH.reply(m,$LOAD_PATH.inspect)
      when "lift" :
        EM.spawn do
          worker = WH::Actions::Worker.new
          worker.callback {WH.reply(m, "Done lifting")}
          worker.heavy_lifting
        end.notify
        WH.reply(m, "Scheduled heavy job...")
      when "pull" :
        EM.spawn do
          worker = WH::Actions::Worker.new
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
}

# Register MUC message handler
WH::Actions.handle_muc('worker') { |cn,muc|
  muc.add_message_callback do |m|
    fromus = "#{cn}/#{muc.nick}"
    if m.from != fromus
      if m.body == 'test'
        WH.reply_muc(muc, m, "Got your test!")
      elsif WH::Config.base.group_default_response
        WH.reply_muc(muc, m, "Dunno how to #{m.body}")
      end
    end
  end
}