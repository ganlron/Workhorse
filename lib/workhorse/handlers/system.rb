module Workhorse
  module Actions
    class System
      include WH::Actions::Handler
      VERSION = "0.01"
      DESCRIPTION = "System Information Query"
      REQUIREMENTS = []
      
      def uptime
        res = self.system("uptime").chomp
        self.succeeded(res)
      end
      
      def hardware
        res = self.system("uname -m").chomp
        self.succeeded(res)
      end
      
      def kernel
        res = self.system("uname -i").chomp
        self.succeeded(res)
      end
      
      def hostname
        res = self.system("uname -n").chomp
        self.succeeded(res)
      end
      
      def os
        res = self.system("uname -sr").chomp
        self.succeeded(res)
      end
      
      def handle
        self.nonblocking(@command)
      end

    end
  end
end

WH::Actions.add_handle('system',WH::Actions::System)