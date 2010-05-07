# netGUARD Queue Management Module

require 'rubygems'
require 'eventmachine'
require 'resolv'
require 'net/smtp'

module Workhorse
  module Actions
    class Exim
      include EM::Deferrable
      
      @@exim = File.exists?("/usr/local/bin/exim") ? "/usr/local/bin/exim" : File.exists?("/usr/bin/exim") ? "/usr/bin/exim" : nil
      @@mailq = File.exists?("/usr/bin/mailq") ? "/usr/bin/mailq" : nil
      @@exiqsumm = File.exists?("/usr/local/bin/exiqsumm") ? "/usr/local/bin/exiqsumm" : File.exists?("/usr/bin/exiqsumm") ? "/usr/bin/exiqsumm" : nil
      @@xargs = File.exists?("/usr/bin/xargs") ? "/usr/bin/xargs" : nil

      def mailq
        if @@mailq
          messages = Array.new
          msg = nil
          
          mailq = %x{#{@@mailq} 2>&1}

          mailq.each do |m|
              if m =~ /^\s*(.+?)\s+(.+?)\s+(.+-.+-.+) <(.*)>/
                  msg = {}
                  msg[:recipients] = Array.new
                  msg[:frozen] = false

                  msg[:age] = $1
                  msg[:size] = $2
                  msg[:msgid] = $3
                  msg[:sender] = $4

                  msg[:frozen] = true if m =~ /frozen/
              elsif m =~ /\s+(\S+?)@(.+)/ and msg
                  msg[:recipients] << "#{$1}@#{$2}"
              elsif m =~ /^$/ && msg
                  messages << msg
                  msg = nil
              end
          end
          
          messages
        end
      end
      
      def mailq_response
        response = "There is no queued mail"
        unless mailq.empty?
          response = "The following messages are queued:\n\n"
          mailq.each do |m|
            response << "Message #{m[:msgid]} from #{m[:sender]} to #{m[:recipients].join(", ")}\n"
          end
        end
        set_deferred_status :succeeded, response
      end
 
    end
  end
end

module Workhorse
  module Actions
    class EximHandler
      include WH::Actions::Handler
      
      def handle_mailq
        self.nonblocking(WH::Actions::Exim,"mailq_response")
      end

      def handle_none
        next unless @muc.nil?
        self.reply("Exim instructions here")
      end
      
    end
  end
end
WH::Actions.add_handle('exim',WH::Actions::EximHandler)