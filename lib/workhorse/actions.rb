require 'rubygems'
require 'eventmachine'
require 'active_support'
require 'require_all'

module Workhorse
  module Actions
    include EM::Deferrable
    @@handlers = {}
    
    def self.load
      require_all File.dirname(__FILE__) +'/actions'
    end
    
    def self.add_handle(name, c)
      @@handlers[name] = c
    end

    def self.run
      WH.im.add_message_callback do |m|
        if m.type != :error and m.body
          @@handlers.each do |name,c|
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