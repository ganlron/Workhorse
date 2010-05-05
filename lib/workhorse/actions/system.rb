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

module Workhorse
  module Actions
    class SystemHandler
      include WH::Actions::Handler

      def handle_uptime
        EM.spawn do
          whsys = WH::Actions::System.new
          if (@@muc.nil?)
            whsys.callback do |val|
              WH.reply(@@message, val)
            end
          else
            whsys.callback do |val|
              WH.reply_muc(@@muc, @@message, val)
            end
          end
          whsys.uptime
        end.notify
      end
      
    end
  end
end

WH::Actions.add_handle('system',WH::Actions::SystemHandler)