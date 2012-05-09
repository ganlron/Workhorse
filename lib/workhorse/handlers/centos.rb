module Workhorse
  module Actions
    class Centos
      include WH::Actions::Handler
      VERSION = "0.01"
      DESCRIPTION = "Centos Controls"
      
      def update 
        res = self.system("sudo yum -y update")
        self.succeeded(res)
      end
      
      def version 
        res = self.system("cat /etc/issue")
        self.succeeded(res)
      end
      
      def handle
        case @command
        when "update"
          self.blocking("update")
        when "version"
          self.nonblocking("version")
        end
      end
      
    end
  end
end

if File.exists?("/usr/bin/yum")
  WH::Actions.add_handle('centos',WH::Actions::Centos)
end