require 'rubygems'
require 'eventmachine'
require 'resolv'
require 'net/smtp'

module Workhorse
  module Actions
    class TestMX
      include EM::Deferrable
      
      def test(args)
        dom = args.shift
        verbose = args.shift
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
          set_deferred_status :succeeded, res
        else
          set_deferred_status :succeeded, "Domain #{dom} does not exist or did not return MX records"
        end
      end

    end
  end
end

module Workhorse
  module Actions
    class TestMXHandler
      include WH::Actions::Handler

      def handle_test
        if @muc.nil?
          dom = @args.empty? ? nil : @args.shift.downcase
          verbose = @args.empty? ? false : true
          if (dom.nil?)
            self.reply("Please specify the domain to test")
          else
            self.nonblocking(WH::Actions::TestMX,"test",dom,verbose)
            self.reply("Scheduled to test #{dom}...")
          end
        end
      end
    end
  end
end
WH::Actions.add_handle('testmx',WH::Actions::TestMXHandler)