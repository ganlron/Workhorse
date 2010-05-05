require 'rubygems'
require 'eventmachine'
require 'active_support'

module Workhorse
  module Actions
    mattr_accessor :handlers
    include EM::Deferrable
    @@handlers = {}
    
    def self.add_handle(name, c)
      @@handlers[name] = c
    end
    
    def self.identify_request(m)
      words = m.body.squeeze.split(/\s+/)
      h = words.shift.downcase
      c = words.shift.downcase
      return h,c
    end

    def self.run
      WH.im.add_message_callback do |m|
        if WH::Config.user_allowed?(m.from)
          if m.type != :error and m.body
            h,c = self.identify_request(m)
            if @@handlers[h].nil?
              next unless WH::Config.active_handler?(h)
              next unless WH::Config.user_allowed_handler?(m.from,h,c)
              handler = @@handlers[h].new(m)
              if handler.respond_to?("handle_#{c}".to_sym)
                handler.send("handle_#{c}".to_sym)
              end
            else
              if WH::Config.base.direct_default_response
                WH.reply(m,"Sorry, not sure how to deal with #{m.body}")
              end
            end
          end
        end
      end 
    end
  
  def self.run_muc(cn=nil,muc=nil)
    unless cn and muc
      return
    end
    
    muc.add_message_callback do |m|
      unless m.body.nil?
        if m.from != "#{cn}/#{muc.nick}"
          if WH::Config.muc_user_allowed?(m.from)
            h,c = self.identify_request(m)
            unless @@handlers[h].nil?
              next unless WH::Config.active_handler?(h)
              next unless WH::Config.muc_user_allowed_handler?(m.from,h,c)
              handler = @@handlers[h].new(m,muc)
              if handler.respond_to?("handle_#{c}".to_sym)  
                handler.send("handle_#{c}".to_sym)
              end
            end
          else
            if WH::Config.base.group_default_response
              WH.reply(m,"Sorry, not sure how to deal with #{m.body}",muc)
            end
          end
        end
      end
    end
  end
  
  end
end

module Workhorse
  module Actions
    module Handler
      mattr_accessor :message, :muc
      @@message = nil
      @@muc = nil

      def initialize(message=nil,muc=nil)
        @@message = message
        @@muc = muc
      end

    end
  end
end