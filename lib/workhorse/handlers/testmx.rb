require 'resolv'
require 'net/smtp'

module Workhorse
  module Actions
    class TestMX
      include WH::Actions::Handler
      VERSION = "0.01"
      
      def test
        dom = @args[0]
        verbose = @args[1]
        # Pull the MX records for the domain
        dns = Resolv::DNS.open
        mail_servers = dns.getresources(dom, Resolv::DNS::Resource::IN::MX)
        if mail_servers and not mail_servers.empty?
          results = {}
          good = 0
          # Loop through each MX record and attempt an SMTP connection to it
          mail_servers.each do |mx|
            begin
              smtp = Net::SMTP.new(mx.exchange.to_s, 25).start('localhost')
              results[mx.exchange.to_s] = 'PASS'
              good = 1
            rescue Exception
              results[mx.exchange.to_s] = 'FAIL'
            end
          end
          status = good ? "CAN receive e-mail" : "CANNOT receive e-mail"
          res = "#{dom} " + status
          if verbose
            res << "\n\n"
            results.each do |mx,testr|
              res << "#{mx} " << "= " << "#{testr}\n"
            end
          end
          self.succeeded(res)
        else
          self.failed("Domain #{dom} does not exist or did not return MX records")
        end
      end
      
      def handle
        if @muc.nil?
          dom = @args[0]
          if dom.nil?
            # Does command appear to be a domain instead?
            if @command.match(/\./)
              dom = @command
              @args[0] = @command
              @command = "test"
            end
          end
          
          case @command
          when "test"
            if dom.nil?
              self.reply("Please specify the domain to test") unless @type == 'json'
            else
              self.nonblocking("test")
              self.reply("Scheduled to test #{dom}") unless @type == 'json'
            end
          else
            self.reply("TestMX instructions:") unless @type == 'json'
          end
        end    
      end
      
    end
  end
end
WH::Actions.add_handle('testmx',WH::Actions::TestMX)