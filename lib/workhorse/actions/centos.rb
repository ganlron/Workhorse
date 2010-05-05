require 'rubygems'
require 'eventmachine'

module Workhorse
  module Actions
    class Centos
      mattr_accessor :methods
      include EM::Deferrable
      
      @@methods = ["update","version"]

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
      
      WH::Actions::Centos.methods.each do |m|
        define_method "handle_#{m}".to_sym do
          EM.spawn do
            whsys = WH::Actions::Centos.new
            whsys.callback do |val|
              WH.reply(@@message, val, @@muc)
            end
            whsys.send(m.to_sym)
          end.notify
        end
      end

    end
  end
end

WH::Actions.add_handle('centos',WH::Actions::CentosHandler)
