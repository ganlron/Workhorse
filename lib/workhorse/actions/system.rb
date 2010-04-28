require 'rubygems'
require 'eventmachine'

module Workhorse
  module Actions
    class System
      include EM::Deferrable

      def uptime
        res = `uptime`
        set_deferred_status :succeeded, res
      end
      
    end
  end
end

handler = Class.new do
  include WH::Actions::Handler
  def self.handle(m)
    case m.body
    when "system uptime" :
      EM.spawn do
        whsys = WH::Actions::System.new
        whsys.callback do |val|
          WH.reply(m, val)
        end
        whsys.uptime
      end.notify
    end
  end
  
  def self.handle_muc(muc,m)
    case m.body
    when "system uptime" :
      EM.spawn do
        whsys = WH::Actions::System.new
        whsys.callback do |val|
          WH.reply_muc(muc, m, val)
        end
        whsys.uptime
      end.notify
    end
  end
end

WH::Actions.add_handle('system',handler)