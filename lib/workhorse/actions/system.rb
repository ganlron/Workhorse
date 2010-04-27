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

# Register direct message handler
WH::Actions.handle('system') {
  WH.im.add_message_callback do |m|
    if m.type != :error and m.body
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
  end
}

# Register MUC message handler
WH::Actions.handle_muc('system') { |cn,muc|
  muc.add_message_callback do |m| 
    if m.from != "#{cn}/#{muc.nick}"
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
}