require 'rubygems'
require 'eventmachine'

module Workhorse
  module Actions
    class System
      include WH::Actions::Handler
      
      def uptime
        res = self.system("uptime")
        self.succeeded(res)
      end
      
      def hardware
        res = self.system("uname -m")
        self.succeeded(res)
      end
      
      def kernel
        res = self.system("uname -i")
        self.succeeded(res)
      end
      
      def hostname
        res = self.system("uname -n")
        self.succeeded(res)
      end
      
      def os
        res = self.system("uname -sr")
        self.succeeded(res)
      end
      
      def handle
        self.nonblocking(@command)
      end

    end
  end
end

WH::Actions.add_handle('system',WH::Actions::System)