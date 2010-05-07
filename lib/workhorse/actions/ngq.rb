# netGUARD Queue Management Module

require 'rubygems'
require 'eventmachine'
require 'resolv'
require 'net/smtp'

module Workhorse
  module Actions
    class NGQ
      include EM::Deferrable

    end
  end
end

module Workhorse
  module Actions
    class NGQHandler
      include WH::Actions::Handler

      def handle_none
        next unless @muc.nil?
        self.reply("NGQ instructions here")
      end
    end
  end
end
WH::Actions.add_handle('ngq',WH::Actions::NGQHandler)