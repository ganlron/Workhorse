require 'rubygems'
require 'eventmachine'

module Workhorse
  module Actions
    class System
      mattr_accessor :methods
      include EM::Deferrable
      
      @@methods = ["uptime", "hardware", "kernel", "hostname", "os"]

      def uptime
        res = `uptime`
        set_deferred_status :succeeded, res
      end
      
      def hardware
        res = `uname -m`
        set_deferred_status :succeeded, res
      end
      
      def kernel
        res = `uname -i`
        set_deferred_status :succeeded, res
      end
      
      def hostname
        res = `uname -n`
        set_deferred_status :succeeded, res
      end
      
      def os
        res = `uname -sr`
        set_deferred_status :succeeded, res
      end

    end
  end
end

module Workhorse
  module Actions
    class SystemHandler
      include WH::Actions::Handler
      
      WH::Actions::System.methods.each do |m|
        define_method "handle_#{m}".to_sym do
          self.nonblocking(WH::Actions::System,m)
        end
      end

    end
  end
end

WH::Actions.add_handle('system',WH::Actions::SystemHandler)