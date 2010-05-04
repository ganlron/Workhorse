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

    def self.run
      WH.im.add_message_callback do |m|
        if m.type != :error and m.body
          @@handlers.each do |name,c|
            next unless WH::Config.allowed_handler?(name)
            c.handle(m)
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
          @@handlers.each do |name,c|
            next unless WH::Config.allowed_handler?(name)
            c.handle_muc(muc,m)
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

      def self.handle(m)
      end

      def self.handle_muc(muc,m)
      end

    end
  end
end