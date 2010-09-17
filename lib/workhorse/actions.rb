require 'rubygems'
require 'eventmachine'
require 'active_support'
require 'json'

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
      if (m.subject and m.subject == 'json') or (m.body.match(/^\{.+\}$/))
        # Message appears to be a json message, act appropriately
        data = JSON(m.body)
        h = data["handler"] ? data["handler"] : nil
        c = data["command"] ? data["command"] : "none"
        words = data["args"] ? data["args"].gsub(/\302\240/," ").squeeze(" ").split(/\s+/) : []
        type = "json"
      else
        words = m.body.gsub(/\302\240/," ").squeeze(" ").split(/\s+/)
        h = words.shift.downcase
        c = words.empty? ? "none" : words.shift.downcase
        type = "text"
      end
      return h,c,type,words
    end

    def self.run
      WH.im.add_message_callback do |m|
        if WH::Config.user_allowed?(m.from)
          if m.type != :error and m.body
            h,c,t,w = self.identify_request(m)
            if !@@handlers[h].nil?
              next unless WH::Config.active_handler?(h)
              next unless WH::Config.user_allowed_handler?(m.from,h,c)
              handler = @@handlers[h].new(m,c,t,w)
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
            h,c,t,w = self.identify_request(m)
            if !@@handlers[h].nil?
              next unless WH::Config.active_handler?(h)
              next unless WH::Config.muc_user_allowed_handler?(m.from,h,c)
              handler = @@handlers[h].new(m,c,t,w,muc)
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
      @type="text"
      @args = []

      def initialize(message=nil,command=nil,type="text",args=[],muc=nil)
        @message = message
        @command = command
        @args = args
        @muc = muc
        @type = type
      end
      
      def reply(response="Dunno how to")
        if (@type == 'json')
          # Pack up a json response
          newr = {
            "response" => response
          }
          response = newr.to_json
        end
        r = Message.new(@message.from, response)
        r.type = @message.type
        r.subject = @type
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