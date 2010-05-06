require 'rubygems'
require 'eventmachine'

module Workhorse
  module Actions
    class Centos
      mattr_accessor :methods
      include EM::Deferrable
      
      def update 
        res = `sudo yum -y update`
        set_deferred_status :succeeded, res
      end
      
      def version 
        res = `cat /etc/issue`
        set_deferred_status :succeeded, res
      end
      
    end
  end
end

module Workhorse
  module Actions
    class CentosHandler
      include WH::Actions::Handler
      
      def handle_update
        EM.spawn do |mess,muc|
          co = WH::Actions::Centos.new
          co.callback do |val|
            WH.reply(mess, val, muc)
          end
          co.update
        end.notify @message, @muc
      end
      
      def handle_version
        EM.spawn do |mess,muc|
          co = WH::Actions::Centos.new
          co.callback do |val|
            WH.reply(mess, val, muc)
          end
          Thread.new { co.version }
        end.notify @message, @muc
      end
      
    end
  end
end

WH::Actions.add_handle('centos',WH::Actions::CentosHandler)
