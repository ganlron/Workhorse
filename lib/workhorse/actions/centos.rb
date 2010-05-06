require 'rubygems'
require 'eventmachine'

module Workhorse
  module Actions
    class Centos
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
        self.blocking(WH::Actions::Centos,"update")
      end
      
      def handle_version
        self.nonblocking(WH::Actions::Centos,"version")
      end
      
    end
  end
end

WH::Actions.add_handle('centos',WH::Actions::CentosHandler)
