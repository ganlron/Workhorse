require 'rubygems'
require 'eventmachine'
require 'active_support'
require 'configatron'

module Workhorse
  module Config
    mattr_accessor :daemon, :base, :im, :handlers, :users, :muc_handles
    
    # Load default configuration
    wh_config = configatron
    wh_config.configure_from_hash({
      :daemon => {
        :user => 'workhorse',
        :group => 'workhorse',
        :client_syslog_facility => 'daemon'
      },
      :base => {
        :use_sudo => true,
        :sudo_path => '/usr/local/bin/sudo',
        :direct_default_response => false,
        :group_default_response => false
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
    workhorse_local_conf = File.join(File.dirname(__FILE__),'../../config/workhorse_local.yml')
    if (File.exists?(workhorse_local_conf))
      wh_config.configure_from_yaml( workhorse_local_conf )
    end
    
    # Load daemon local configuration
    daemon_local_conf = File.join(File.dirname(__FILE__),'../../config/daemon_local.yml')
    if (File.exists?(daemon_local_conf))
      wh_config.configure_from_yaml( daemon_local_conf )
    end
    
    # Load handlers local configuration
    handlers_local_conf = File.join(File.dirname(__FILE__),'../../config/handlers_local.yml')
    if (File.exists?(handlers_local_conf))
      wh_config.configure_from_yaml( handlers_local_conf )
    end
    
    # Load users local configuration
    users_local_conf = File.join(File.dirname(__FILE__),'../../config/users_local.yml')
    if (File.exists?(users_local_conf))
      wh_config.configure_from_yaml( users_local_conf )
    end
    
    wh_config.lock!
    @@im = wh_config.im
    @@base = wh_config.base
    @@daemon = wh_config.daemon
    @@handlers = wh_config.handlers
    @@users = wh_config.users
    @@muc_handles = wh_config.muc_handles
    
    def self.active_handler?(handle)
      self.handlers.retrieve(handle,false)
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
    
  end
end