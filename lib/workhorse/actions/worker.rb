module Workhorse
  module Actions
    class Worker
      include WH::Actions::Handler
      VERSION = "0.01"
      
      def heavy_lifting
        30.times do |i|
          puts "Lifted #{i}"
          sleep 0.1
        end
        self.succeeded("Done lifting")
      end
  
      def heavy_pulling
        60.times do |i|
          puts "Pulled #{i}"
          sleep 0.1
        end
        self.succeeded("Done pulling")
      end

      def handle
        case @command
        when "test"
          self.reply("Test Received")
        when "ipath"
          self.reply($LOAD_PATH.inspect)
        when "lift"
          if @muc.nil?
            self.nonblocking("heavy_lifting")
            self.reply("Scheduled lift")
          end
        when "pull"
          if @muc.nil?
            self.nonblocking("heavy_pulling")
            self.reply("Scheduled pull")
          end
        end
      end
      
    end
  end
end

WH::Actions.add_handle('worker',WH::Actions::Worker)