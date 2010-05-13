require 'rubygems'
require 'eventmachine'
require 'active_support'

module Workhorse
  module Actions
    mattr_accessor :handlers
    include EM::Deferrable
    VERSION = "0.01"
    @@handlers = {}
    
    def self.add_handle(name, c)
      @@handlers[name] = c
    end
    
    def self.identify_request(m)
      words = m.body.squeeze(" ").split(/\s+/)
      h = words.shift.downcase
      c = words.empty? ? "none" : words[0].downcase
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
              handler = @@handlers[h].new(m,c,w)
              if handler.respond_to?("handle".to_sym)
                handler.handle
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
              handler = @@handlers[h].new(m,c,w,muc)
              if handler.respond_to?("handle".to_sym)
                handler.handle
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
      include EM::Deferrable
      VERSION = "0.01"
      DESCRIPTION = nil
      @message = nil
      @command = nil
      @muc = nil
      @args = []

      def initialize(message=nil,command=nil,args=[],muc=nil)
        @message = message
        @command = command
        @args = args
        @muc = muc
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

      def blocking(m,&a)
        return unless self.respond_to?(m.to_sym)
        EM.spawn do |this,a|
          this.callback do |response|
            this.reply(response) if response
            a.call(this) if a
          end
          this.errback do |response|
            this.reply(response) if response
          end
          this.send(m.to_sym)
        end.notify self,a
      end
      
      def nonblocking(m,&a)
        return unless self.respond_to?(m.to_sym)
        EM.spawn do |this,a|
          this.callback do |response|
            this.reply(response) if response
            a.call(this) if a
          end
          this.errback do |response|
            this.reply(response) if response
          end
          Thread.new { this.send(m.to_sym) }
        end.notify self,a
      end
      
      def succeeded(response=nil)
        set_deferred_status :succeeded, response
      end
      
      def failed(response="Command failed")
        set_deferred_status :failed, response
      end
      
      def system(c)
         %x{#{c} 2>&1}
      end
      
    end
  end
end