require 'rubygems'
require 'eventmachine'
require 'active_support'
require 'configatron'

module Workhorse
  module Config
    mattr_accessor :daemon, :base, :im, :handlers, :users, :muc_handles
    VERSION = "0.01"

    def self.load_local_config(name)
      path = @wh_config.base.retrieve(name.to_sym,nil)
      if path
        if (File.exists?(path))
          @wh_config.configure_from_yaml( path )
        end
      end
    end
    
    def self.set_vars
      @@im = @wh_config.im
      @@base = @wh_config.base
      @@daemon = @wh_config.daemon
      @@handlers = @wh_config.handlers
      @@users = @wh_config.users
      @@muc_handles = @wh_config.muc_handles
    end

    def self.active_handler?(handle)
      self.handlers.retrieve(handle,false)
    end
    
    def self.user_defined?(user)
      dom,node,resource = self.split_jid(user.downcase)
      users = self.users.to_hash
      user = users[dom.to_sym][node.to_sym]
      return false if user.nil?
      return true
    end
    
    def self.user_allowed?(user)
      dom,node,resource = self.split_jid(user)
      users = self.users.to_hash
      user = users[dom.to_sym][node.to_sym]
      return false if user.nil?
      return false if user[:allowed].nil?
      return false if user[:allowed] == 'none'
      return true
    end
    
    def self.muc_user_allowed?(user)
      muc_handle = self.link_muc(user)
      return false if muc_handle.nil?
      self.user_allowed?(muc_handle)
    end
    
    def self.user_allowed_handler?(user,handler,command = nil)
      dom,node,resource = self.split_jid(user)
      users = self.users.to_hash
      user = users[dom.to_sym][node.to_sym]
      return false if user.nil?
      return true if user[:allowed] == 'all'
      return false if user[:handlers].nil?
      h = user[:handlers][handler.to_sym]
      return false if h.nil?
      return false if h[:allowed].nil?
      return true if h[:allowed] == 'all'
      if (command.nil?)
        return true if h[:allowed] == 'limited'
      else
        c = h[:commands]
        return false if c.nil?
        return false if c[command.to_sym].nil?
        return true if c[command.to_sym] == 'allowed'
      end
      return false
    end
    
    def self.muc_user_allowed_handler?(user,handler,command = nil)
      muc_handle = self.link_muc(user)
      return false if muc_handle.nil?
      self.user_allowed_handler?(muc_handle,handler,command)
    end
    
    def self.split_jid(user)
      jid = Jabber::JID.new(user)
      dom = jid.domain.gsub(/[\.\@]/, '_').downcase
      node = jid.node.gsub(/[\.\@]/, '_').downcase unless jid.node.nil?
      resource = jid.resource.gsub(/[\.\@]/, '_').downcase unless jid.resource.nil?
      return dom, node, resource
    end
    
    def self.link_muc(handle)
      dom,node,resource = self.split_jid(handle)
      muc_handles = self.muc_handles.to_hash
      return muc_handles[dom.to_sym][resource.to_sym]
    end
    
    def self.write_yaml_local_config(config_name=nil,config_hash=nil)
      return false unless config_name and config_hash
      path = self.base.retrieve(config_name.to_sym,nil)
      return false unless path
      if File.exists?(path) and File.writable?(path)
        File.open( path, 'w' ) do |out|
          YAML.dump( config_hash, out )
        end
        self.load_local_config(config_name)
        self.set_vars
        return true
      else
        return false
      end
    end
    
    def self.add_user(user=nil)
      if user and user.match(/^[^@]+@[^@]+$/)
        if self.user_defined?(user)
          return false
        else
          lp,dom = user.downcase.split('@')
          u = WH::Config.users.to_hash
          m = WH::Config.muc_handles.to_hash
          u[dom.gsub(/[^\w]/,"_").to_sym][lp.gsub(/[^\w]/,"_").to_sym] = {
            :allowed => "none"
          }
          config = {
            :users => u,
            :muc_handles => m
          }
          if self.write_yaml_local_config("users_local_conf",config)
            return true
          else
            return false
          end
        end
      end
    end
    
    def self.add_handle(user=nil,handle=nil)
      return false unless user and handle
      if user.match(/^[^@]+@[^@]+$/) and handle.match(/^[^\/]+\/[^\/]+$/)
        if self.user_defined?(user)
          server,nick = handle.downcase.split('/')
          u = WH::Config.users.to_hash
          m = WH::Config.muc_handles.to_hash
          m[server.gsub(/[^\w]/,"_").to_sym][nick.gsub(/[^\w]/,"_").to_sym] = user.to_s
          config = {
            :users => u,
            :muc_handles => m
          }
          if self.write_yaml_local_config("users_local_conf",config)
            return true
          else
            return false
          end
        else
          return false
        end       
      else
        return false
      end
    end
    
    def self.add_access(user=nil,handler=nil,*commands)
    end
        
    # Load default configuration
    @wh_config = configatron
    @wh_config.configure_from_hash({
      :daemon => {
        :user => 'workhorse',
        :group => 'workhorse',
        :client_syslog_facility => 'daemon'
      },
      :base => {
        :use_sudo => true,
        :sudo_path => '/usr/local/bin/sudo',
        :direct_default_response => false,
        :group_default_response => false,
        :workhorse_local_conf => File.join(File.dirname(__FILE__),'../../config/workhorse_local.yml'),
        :daemon_local_conf => File.join(File.dirname(__FILE__),'../../config/daemon_local.yml'),
        :handlers_local_conf => File.join(File.dirname(__FILE__),'../../config/handlers_local.yml'),
        :users_local_conf => File.join(File.dirname(__FILE__),'../../config/users_local.yml'),
        
      },
      :im => {
        :jid => 'username@staff.csolve.net',
        :domain => 'staff.csolve.net',
        :resource => 'Servers',
        :password => 'password',
        :channels => {
          'allservers@conference.staff.csolve.net' => {
            :nick => 'nickname',
            :password => 'server4u'
          }
        }
      },
      :handlers => {
        :system => true,
      },
      :users => {
      },
      :muc_handles => {
      }
    })
    
    # Load workhorse local configuration
    self.load_local_config("workhorse_local_conf")
    
    # Load daemon local configuration
    self.load_local_config("daemon_local_conf")
    
    # Load handlers local configuration
    self.load_local_config("handlers_local_conf")
    
    # Load users local configuration
    self.load_local_config("users_local_conf")
    
    self.set_vars
  end
end