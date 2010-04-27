require 'rubygems'
require 'eventmachine'
require 'active_support'
require 'require_all'

module Workhorse
  module Actions
    include EM::Deferrable
    @@handlers = {}
    @@muc_handlers = {}
    
    def self.load
      require_all File.dirname(__FILE__) +'/actions'
    end
    
    def self.handle(name, &block)
      @@handlers[name] = block
    end

    def self.handle_muc(name, &block)
      @@muc_handlers[name] = block
    end

    def self.run
      @@handlers.each do |name,block|
        block.call
      end
    end
  
  def self.run_muc(cn=nil,muc=nil)
    unless cn and muc
      return
    end
    
    @@muc_handlers.each do |name,block|
      block.call(cn,muc)
    end
  end
  
  end
end