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
        WH.reply(@message,ret, @muc)
      end
      
      def handle_ipath
        ret = $LOAD_PATH.inspect
        WH.reply(@message,ret, @muc)
      end
      
      def handle_lift
        if @muc.nil?
          EM.spawn do |mess|
            worker = WH::Actions::Worker.new
            worker.callback {WH.reply(mess, "Done lifting")}
            Thread.new { worker.heavy_lifting }
          end.notify @message
          WH.reply(@message, "Scheduled heavy job...")
        end
      end
      
      def handle_pull
        if @muc.nil?
          EM.spawn do |mess|
            worker = WH::Actions::Worker.new
            worker.callback {WH.reply(mess, "Done pulling")}
            Thread.new { worker.heavy_pulling }
          end.notify @message
          WH.reply(@message, "Scheduled heavy job...")
        end
      end
      
    end
  end
end

WH::Actions.add_handle('worker',WH::Actions::WorkerHandler)