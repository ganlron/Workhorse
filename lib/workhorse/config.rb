$LOAD_PATH.unshift( File.join(File.dirname(__FILE__),'../lib') );
require 'rubygems'
require 'eventmachine'
require 'active_support'
require 'configatron'

module Workhorse
  module Config
    mattr_accessor :daemon, :base, :im
    
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
    
    @@im = wh_config.im
    @@base = wh_config.base
    @@daemon = wh_config.daemon
    
  end
end