$LOAD_PATH.unshift( File.join(File.dirname(__FILE__),'../lib') );
require 'rubygems'
require 'eventmachine'
require 'active_support'
require 'workhorse/worker'

module Workhorse
  module Actions
    include EM::Deferrable

    def self.run
      Workhorse.im.received_messages do |message|
        Workhorse.log("Received message from #{message.from}: #{message.body}")
        case message.body
        when "lift" :
          EM.spawn do
            worker = Worker.new
            worker.callback {Workhorse.im.deliver(message.from, "Done lifting")}
            worker.heavy_lifting
          end.notify
          Workhorse.log("Sending message to #{message.from}: Scheduled heavy job...")
          Workhorse.im.deliver(message.from, "Scheduled heavy job...")
        when "pull" :
          EM.spawn do
            worker = Worker.new
            worker.callback {Workhorse.im.deliver(message.from, "Done pulling")}
            worker.heavy_pulling
          end.notify
          Workhorse.im.deliver(message.from, "Scheduled heavy job...")
        else Workhorse.im.deliver(message.from, "Dunno how to #{message.body}")
        end
      end
    end
  end
end