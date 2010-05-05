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
          whsys.callback do |val|
            WH.reply(@@message, val, @@muc)
          end
          whsys.uptime
        end.notify
      end
      
    end
  end
end

WH::Actions.add_handle('system',WH::Actions::SystemHandler)