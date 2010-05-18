require 'yaml'
module Workhorse
  module Actions
    class Workhorse
      include WH::Actions::Handler
      VERSION = "0.01"
      DESCRIPTION = "Administrative controls for Workhorse"
      
      def versions
        versions = {}
        versions["app"] = {}
        versions["app"]["workhorse"] = WH::VERSION
        versions["app"]["config"] = WH::Config::VERSION
        versions["app"]["handlers"] = WH::Actions::VERSION
        versions["handlers"] = {}
        WH::Actions.handlers.each do |h,c|
          versions["handlers"][h] = c::VERSION
        end
        versions
      end
      
      def version_response
        if @args[1]
          if versions["handlers"][@args[1]]
            self.succeeded("Version #{versions["handlers"][@args[1]]} of handler #{@args[1]} installed")
          else
            self.failed("Cannot find an installed version of handler #{@args[1]}")
          end
        else
          res = "Application:\n"
          versions["app"].each do |h,v|
            res << "\t#{h} = #{v}\n"
          end
          res << "\nActions:\n"
          versions["handlers"].sort.each do |h,v|
            res << "\t#{h} = #{v}\n"
          end
          self.succeeded(res)
        end
      end
      
      def handlers
        handlers = {}
        WH::Actions.handlers.each do |h,c|
          handlers[h] = {
            :version => c::VERSION,
            :desc => c::DESCRIPTION,
            :active => WH::Config.active_handler?(h)
          }
        end
        handlers
      end
      
      def handler_response
        res_handlers = {}
        handlers.each do |h,i|
          if @args[1]
            next if @args[1].match(/^active$/i) and !i[:active]
            next if @args[1].match(/^inactive$/i) and i[:active]
          end
          res_handlers[h] = i
        end
        
        if res_handlers.empty?
          if @args[1]
            case @args[1]
            when /^active$/i
              res = "There are currently no active handlers"
            when /^inactive$/i
              res = "There are currently no inactive handlers"
            else
              res = "There are no installed handlers"
            end
          else
            res = "There are no installed handlers"
          end
        else
          res = "Handlers:\n"
          res_handlers.sort.each do |h,i|

            res << "\t#{h} (#{i[:version]})"
            unless i[:desc].nil?
              res << " - #{i[:desc]}"
            end
            res << "\n"
          end
        end
        self.reply(res)
      end
      
      def users
        users = {}
        u = WH::Config.users.to_hash
        u.each do |d,list|
           dom = d.to_s.gsub(/_/,'.')
           list.each do |u,a|
             user = u.to_s + '@' + dom
             users[user] = a
           end
        end
        users
      end
      
      def handles
        handles = {}
        list = WH::Config.muc_handles.to_hash
        list.each do |d,hl|
           dom = d.to_s.gsub(/_/,'.')
           hl.each do |h,v|
             handle = dom + '/' + h.to_s
             handles[handle] = v
           end
        end
        handles
      end
      
      def add_user
        if @args[2] and @args[2].match(/^[^@]+@[^@]+$/)
          user = @args[2].downcase
          if WH::Config.add_user(user)
            self.succeeded("User #{user} was successfully added to Workhorse")
          else
            self.failed("Failed to add user #{user}")
          end
        else
          self.failed("Please supply a username in the format of username@domain")
        end
      end
      
      def rm_user
        if @args[2] and @args[2].match(/^[^@]+@[^@]+$/)
          user = @args[2].downcase
          if WH::Config.rm_user(user)
            self.succeeded("User #{user} was successfully removed from Workhorse")
          else
            self.failed("Failed to remove user #{user}")
          end
        else
          self.failed("Please supply a username in the format of username@domain")
        end
      end
      
      def add_handle
        if @args[2] and @args[2].match(/^[^@]+@[^@]+$/) and @args[3] and @args[3].match(/^[^\/]+\/[^\/]+$/)
          handle = @args[2].downcase
          link = @args[3].downcase
          if WH::Config.add_handle(handle,link)
            self.succeeded("Handle #{handle} was successfully added to Workhorse")
          else
            self.failed("Failed to add handle #{handle}")
          end
        else
          self.failed("Please supply both the username (in the format of username@domain) to link to, as well as the handle (in the format of server/nick) to link")
        end
      end
      
      def rm_handle
        if @args[2] and @args[2].match(/^[^\/]+\/[^\/]+$/)
          handle = @args[2].downcase
          if WH::Config.rm_handle(handle)
            self.succeeded("Handle #{handle} was successfully removed from Workhorse")
          else
            self.failed("Failed to remove handle #{handle}")
          end
        else
          self.failed("Please supply the handle (in the format of server/nick) to remove")
        end
      end
      
      def add_access
        if @args[2] and @args[2].match(/^[^@]+@[^@]+$/) and @args[3]
          user = @args[2].downcase
          handler = @args[3].downcase
          commands = @args.slice(4..-1)
          if WH::Config.add_access(user,handler,commands)
            self.succeeded("Access to #{handler} for #{user} was successfully added to Workhorse")
          else
            self.failed("Failed to add access to #{handler} for #{user}")
          end
        else
          self.succeeded("Please supply both the username and the handler/action to grant access to")
        end
      end
      
      def rm_access
        if @args[2] and @args[2].match(/^[^@]+@[^@]+$/)
          user = @args[2].downcase
          handler = @args[3]
          commands = @args.slice(4..-1)
          # if no handler supplied, redirect to rm_user
          self.rm_user unless handler
          if WH::Config.rm_access(user,handler,commands)
            self.succeeded("Access to #{handler} for #{user} was successfully removed from Workhorse")
          else
            self.failed("Failed to remove access to #{handler} for #{user}")
          end
        else
          self.succeeded("Please the username to remove access from, and optionally the handler and/or command(s)")
        end
      end

      def handle
        case @command
        when "version"
          self.nonblocking("version_response")
        when "handlers"
          self.nonblocking("handler_response")
        when "users"
          res = "User List:\n\n"
          users.sort.each do |u,a|
            res << "#{u}\n"
            if a[:allowed] and a[:allowed] != "none"
              res << "\tAccess: #{a[:allowed]}\n"
              if a[:allowed] == "limited"
                unless a[:handlers].empty?
                  res << "\tActions:\n"
                  a[:handlers].each do |handler,perms|
                    res << "\t\t#{handler}\n"
                    if perms[:allowed] and perms[:allowed] != "none"
                      res << "\t\t\tAccess: #{perms[:allowed]}\n"
                      if perms[:allowed] == "limited"
                        unless perms[:commands].empty?
                          res <<"\t\t\tCommands:\n"
                          perms[:commands].each do |command,val|
                            res << "\t\t\t\t#{command}: #{val}\n"
                          end
                        end
                      end
                    else
                      res << "\t\t\tAccess: none\n"
                    end
                  end
                end
              end
            else
              res << "\tAccess: none\n"
            end
            res << "\n"
          end
          self.reply(res)
        when "handles"
          if handles.empty?
            self.reply("There are no defined MUC handles")
          else
            res = "MUC Handles:\n\n"
            handles.each do |handle,link|
              res << "#{handle}: #{link}\n"
            end
            self.reply(res)
          end
        when "add"
          if @args[1]
            case @args[1]
            when /^user$/i
              self.blocking("add_user")
            when /^handle$/i
              self.blocking("add_handle")
            when /^access$/i
              self.blocking("add_access")
            else
              self.reply("Not sure what you're trying to add (please see help)")
            end
          else
            self.reply("What would you like to add?")
          end
        when "remove", "rm"
          if @args[1]
            case @args[1]
            when /^user$/i
              self.blocking("rm_user")
            when /^handle$/i
              self.blocking("rm_handle")
            when /^access$/i
              self.blocking("rm_access")
            else
              self.reply("Not sure what you're tryig to remove (please see help)")
            end
          else
            self.reply("What would you like to remove?")
          end
        else
          help = "Usage: workhorse <command> <optional>\n\n" +
          "Information Commands:\n" +
          "\tversion - Displays version information on program and installed handlers\n" +
          "\t\tOptions:\n" +
          "\t\t\t<handler> - Supply name of handler to limit display\n" +
          "\thandlers - Provides a list of installed handlers\n" +
          "\t\tOptions:\n" +
          "\t\t\tall - Lists all handlers (default)\n" +
          "\t\t\tactive - Lists all active handlers\n" +
          "\t\t\tinactive - Lists all inactive handlers\n" +
          "\tusers - Provides a list of recognized users\n" +
          "\thandles - Provides a list of recognized MUC Handles/Aliases/Nicknames and the associated user\n" +
          "\nAdministration Commands:\n" +
          "\tadd - Add something" +
          "\t\tOptions:\n" +
          "\t\t\tuser - Adds a user with no access\n" +
          "\t\t\t\t(required <user> - username@domain to add)\n" +
          "\t\t\thandle - Adds a MUC handle with link to valid user\n" +
          "\t\t\t\t(required <link> - username@domain to link to, <handle> - server/nick to be linked to user)\n" +
          "\t\t\taccess - Grants user access to an handler\n" +
          "\t\t\t\t(required <user> - username@domain to be granted access, <handler> - Name of handler to grant access to, <commands> - (Optional) - list of commands to limit access to)\n" +
          "\tremove - Remove something" +
          "\t\tOptions:\n" +
          "\t\t\tuser - Removes a non superuser\n" +
          "\t\t\t\t(required <user> - username@domain to remove)\n" +
          "\t\t\thandle - Removes a MUC handle with link to valid user\n" +
          "\t\t\t\t(required <handle> - Handle/Alias to remove)\n" +
          "\t\t\taccess - Denies user access to an handler\n" +
          "\t\t\t\t(required <user> - username@domain to be denied access, <handler> - (Optional) - Name of handler to deny access to, <commands> - (Optional) - list of commands to remove access from)\n"
          
          self.reply(help)
        end
      end
  
    end
  end
end
WH::Actions.add_handle('workhorse',WH::Actions::Workhorse)
WH::Actions.add_handle('wh',WH::Actions::Workhorse)