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
        set_deferred_status :succeeded, "Done lifting"
      end
  
      def heavy_pulling
        60.times do |i|
          puts "Pulled #{i}"
          sleep 0.1
        end
        set_deferred_status :succeeded, "Done pulling"
      end
    end
  end
end

module Workhorse
  module Actions
    class WorkerHandler
      include WH::Actions::Handler

      def handle_test
        self.reply("Test Received")
      end
      
      def handle_ipath
        self.reply($LOAD_PATH.inspect)
      end
      
      def handle_lift
        if @muc.nil?
          self.nonblocking(WH::Actions::Worker,"heavy_lifting")
          self.reply("Scheduled heavy job...")
        end
      end
      
      def handle_pull
        if @muc.nil?
          self.nonblocking(WH::Actions::Worker,"heavy_pulling")
          self.reply("Scheduled heavy job...")
        end
      end
      
    end
  end
end

WH::Actions.add_handle('worker',WH::Actions::WorkerHandler)