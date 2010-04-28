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

handler = Class.new do
  include WH::Actions::Handler
  def self.handle(m)
    WH.log("Received message from #{m.from}: #{m.body}")
    case m.body
      when "test" :
        WH.reply(m,"Test received")
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
    end
  end
  
  def self.handle_muc(muc,m)
    if m.body == 'test'
      WH.reply_muc(muc, m, "Got your test!")
    end
  end
end

WH::Actions.add_handle('worker',handler)