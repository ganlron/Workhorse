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

module Workhorse
  module Actions
    class WorkerHandler
      include WH::Actions::Handler

      def handle_test
        ret = "Test Received"
        if (@@muc.nil?)
          WH.reply(@@message,ret)
        else
          WH.reply_muc(@@muc, @@message, ret) 
        end
      end
      
      def handle_ipath
        ret = $LOAD_PATH.inspect
        if (@@muc.nil?)
          WH.reply(@@message,ret)
        else
          WH.reply_muc(@@muc, @@message, ret)
        end
      end
      
      def handle_lift
        EM.spawn do
          worker = WH::Actions::Worker.new
          worker.callback {WH.reply(@@message, "Done lifting")}
          worker.heavy_lifting
        end.notify
        WH.reply(@@message, "Scheduled heavy job...")
      end
      
      def handle_pull
        EM.spawn do
          worker = WH::Actions::Worker.new
          worker.callback {WH.reply(@@message, "Done pulling")}
          worker.heavy_pulling
        end.notify
        WH.reply(@@message, "Scheduled heavy job...")
      end
      
    end
  end
end

WH::Actions.add_handle('worker',WH::Actions::WorkerHandler)