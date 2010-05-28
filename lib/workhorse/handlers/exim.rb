# netGUARD Queue Management Module
module Workhorse
  module Actions
    class Exim
      include WH::Actions::Handler
      VERSION = "0.01"
      DESCRIPTION = "Query and control Exim"
      
      @@exim = File.exists?("/usr/local/sbin/exim") ? "/usr/local/sbin/exim" : File.exists?("/usr/sbin/exim") ? "/usr/sbin/exim" : nil
      if WH::Config.base.use_sudo and !@@exim.nil?
        @@exim = WH::Config.base.sudo_path + ' ' + @@exim
      end
      @@mailq = File.exists?("/usr/bin/mailq") ? "/usr/bin/mailq" : nil
      @@exiqsumm = File.exists?("/usr/local/sbin/exiqsumm") ? "/usr/local/sbin/exiqsumm" : File.exists?("/usr/sbin/exiqsumm") ? "/usr/sbin/exiqsumm" : nil
      if WH::Config.base.use_sudo and !@@exiqsumm.nil?
        @@exiqsumm = WH::Config.base.sudo_path + ' ' + @@exiqsumm
      end
      @@exiqgrep = File.exists?("/usr/local/sbin/exiqgrep") ? "/usr/local/sbin/exiqgrep" : File.exists?("/usr/sbin/exiqgrep") ? "/usr/sbin/exiqgrep" : nil
      if WH::Config.base.use_sudo and !@@exiqgrep.nil?
        @@exiqgrep = WH::Config.base.sudo_path + ' ' + @@exiqgrep
      end
      @@xargs = File.exists?("/usr/bin/xargs") ? "/usr/bin/xargs" : nil

      def mailq
        if @@mailq
          messages = Hash.new
          msg = nil
          
          mailq = self.system(@@mailq)

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
              messages[msg[:msgid]] = msg
              msg = nil
            end
          end
          messages[msg[:msgid]] = msg unless msg.nil?

          messages
        end
      end
      
      def mailq_response
        response = "There is no queued mail"
        if self.size > 100
          response = "There are more than 100 messages queued"
        else
          unless mailq.empty?
            response = "The following messages are queued:\n\n"
            mailq.each do |id,m|
              response << "Message #{id} from #{m[:sender]} to #{m[:recipients].join(", ")}\n"
            end
          end
        end
        self.succeeded(response)
      end
      
      def size
        mailq.size
      end
      
      def size_response
        self.succeeded(size)
      end
      
      def summary
        if @@mailq and @@exiqsumm
          qsumm = self.system("#{@@mailq} 2>&1 | #{@@exiqsumm}")
          stats = Hash.new
          qsumm.each do |q|
              domain = nil

              if q =~ /^\W+(\d+)\W+(\d+\w+)\W+(\w+)\W+(\w+)\W+(.+)$/
                  domain = {}

                  domain[:count] = $1
                  domain[:volume] = $2
                  domain[:oldest] = $3
                  domain[:newest] = $4
                  domain[:domain] = $5.downcase

                  stats[domain[:domain].downcase] = domain unless $5 == "TOTAL" && $1 =~ /\d+/
              end
          end

          stats
        end
      end
      
      def summary_response
        if @type == 'json'
          response = summary
        else
          response = "There is no queued mail"
          unless summary.empty?
            response = "The following domains are queueing:\n\n"
            summary.each do |d,i|
              response << "#{d} has #{i[:count]} (#{i[:volume]}) messages queued with the oldest being #{i[:oldest]}\n"
            end
          end
        end
        self.succeeded(response)
      end
      
      def queueing
        if summary.empty?
          false
        else
          unless @args[0].nil?
            if @args[1].nil?
              if summary[@args[0].downcase]
                true
              else
                false
              end
            else
              res = summary.map { |k,v| v if k =~ /#{@args[0]}/i }.compact
              if res.empty?
                return false
              else
                return true
              end
            end
          end
        end
      end
      
      def queueing_response
        if @args[0]
          if self.queueing
            if @args[1].nil?
              self.succeeded("Mail is queueing for #{@args[0]}")
            else
              response = ""
              summary.map { |k,v| response << "Mail is queueing for #{v[:domain]}\n" if k =~ /#{@args[0]}/i }.compact
              self.succeeded(response)
            end
          else
            if @args[1].nil?
              self.succeeded("Mail is NOT queueing for #{@args[0]}")
            else
              self.failed("Can not find any mail queueing for pattern #{@args[0]}")
            end
          end
        else
          self.failed("Need a domain to check")
        end
      end
      
      def retry
        if @args[0]
          self.system("#{@@exiqgrep} -r #{@args[0].downcase} -i | #{@@xargs} #{@@exim} -M ")
        else
          self.system("#{@@exim} -q")
        end
      end
      
      def retry_response
        self.retry
        if @args[0]
          @args[1] = 'grep'
          if self.queueing
            self.failed("Retry was attempted, but mail is still queueing for #{@args[0].downcase}")
          else
            self.succeeded("Retry was successful, mail is no longer queueing for #{@args[0].downcase}")
          end
        else
          if self.size > 0
            self.failed("Retry was attempted, but there are still #{self.size} messages queued")
          else
            self.succeeded("Retry was successful, no mail is currently queued")
          end
        end
      end
      
      def rm
        if @args[0]
          res = self.system("#{@@exim} -Mrm #{@args[0]}")
          if res.match(/^Message #{@args[0]} has been removed$/i)
            true
          else
            false
          end
        end
      end
      
      def rmbounces
        out = self.system("#{@@exiqgrep} -i -f '<>' 2>&1").split("\n").join(' ')
        
        return false unless out =~ /-/
        
        self.system("#{@@exiqgrep} -i -f '<>'| #{@@xargs} #{@@exim} -Mrm")
        return true
      end
      
      def handle
        next unless @muc.nil?
        next if @@exim.nil?
        case @command
        when "mailq"
          self.nonblocking("mailq_response")
          self.reply("Processing Mail Queue, please wait...") unless @type == 'json'
        when "size"
          self.nonblocking("size_response")
          self.reply("Processing Mail Queue, please wait...") unless @type == 'json'
        when "summary","qsumm"
          self.nonblocking("summary_response")
          self.reply("Processing Mail Queue, please wait...") unless @type == 'json'
        when "queueing", "queuing"
          self.nonblocking("queueing_response")
          self.reply("Processing Mail Queue, please wait...") unless @type == 'json'
        when "retry"
          self.blocking("retry_response")
          self.reply("Scheduled retry of queued messages...") unless @type == 'json'
        when "rm"
          if @args[0]
            if self.rm
              self.reply("Message #{@args[0]} has been removed")
            else
              self.reply("Failed to remove message #{@args[0]}")
            end
          else
            self.reply("Please supply the message id of the message you wish to remove")
          end
        when "rmbounces"
          if self.rmbounces
            self.reply("Bounce messages have been removed from the queue")
          else
            self.reply("Failed to remove bounce messages")
          end
        else
          help = "Usage: exim <command> <optional>\n\n" +
          "Commands:\n\n" +
          "\tmailq - Returns a list of every message that is queueing\n" +
          "\tsize - Returns a count of how many messages are queueing\n" +
          "\tsummary - Summarizes the queueing messages by recipient domain\n" +
          "\tqueueing <domain|string> <?grep> - Indicate if a domain is queueing, or search for a string using grep\n" +
          "\tretry <?domain> - If a domain is specified will retry queued mail for that domain, otherwise will retry all\n" +
          "\trm <message-id> - Will remove specified message id from the queue\n" +
          "\trmbounces - Will remove all bounces from the queue"
          self.reply(help)
        end
      end

    end
  end
end

if File.exists?("/usr/local/sbin/exim") or File.exists?("/usr/sbin/exim")
  WH::Actions.add_handle('exim',WH::Actions::Exim)
end