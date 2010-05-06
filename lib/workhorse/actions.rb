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
      words = m.body.squeeze(" ").split(/\s+/)
      h = words.shift.downcase
      c = words.empty? ? "none" : words.shift.downcase
      return h,c,words
    end

    def self.run
      WH.im.add_message_callback do |m|
        if WH::Config.user_allowed?(m.from)
          if m.type != :error and m.body
            h,c,w = self.identify_request(m)
            if !@@handlers[h].nil?
              next unless WH::Config.active_handler?(h)
              next unless WH::Config.user_allowed_handler?(m.from,h,c)
              handler = @@handlers[h].new(m,w)
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
            h,c,w = self.identify_request(m)
            if !@@handlers[h].nil?
              next unless WH::Config.active_handler?(h)
              next unless WH::Config.muc_user_allowed_handler?(m.from,h,c)
              handler = @@handlers[h].new(m,w,muc)
              if handler.respond_to?("handle_#{c}".to_sym)
                handler.send("handle_#{c}".to_sym,w)
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
end

module Workhorse
  module Actions
    module Handler
      @message = nil
      @muc = nil
      @args = []

      def initialize(message=nil,args=[],muc=nil)
        @message = message
        @args = args
        @muc = muc
      end
      
      def create_handler(m,type,c,*args)
        return unless m and m.is_a? String
        return unless c and c.is_a? Class
        type = "blocking" unless type and type.is_a? String
        
        define_method "handle_#{m}".to_sym do
          case type
          when "nonblocking"
            self.nonblocking(c,m,*args)
          when "blocking"
            self.blocking(c,m,*args)
          end
        end
      end
      
      def reply(response="Dunno how to")
        r = Message.new(@message.from, response)
        r.type = @message.type
        if @muc.nil?
          WH.im.send(r)
        else
          @muc.send(r)
        end
      end

      def blocking(c,m,*args)
        EM.spawn do |this,args|
          action = c.new
          action.callback do |response|
            this.reply(response)
          end
          if (args.empty?)
            action.send(m.to_sym)
          else
            action.send(m.to_sym,args)
          end
        end.notify self, args
      end
      
      def nonblocking(c,m,*args)
        EM.spawn do |this,args|
          action = c.new
          action.callback do |response|
            this.reply(response)
          end
          Thread.new { 
            if (args.empty?)
              action.send(m.to_sym)
            else
              action.send(m.to_sym,args)
            end
          }
        end.notify self, args
      end
      
    end
  end
end