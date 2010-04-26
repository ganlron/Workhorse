#!/usr/bin/env ruby
$LOAD_PATH.unshift( File.join(File.dirname(__FILE__),'lib') );

require 'rubygems'
require 'daemons'
require 'etc'
require 'workhorse'

def test_drop
  begin
    Process::Sys.setuid(0)
  rescue Errno::EPERM
    true
  else
    false
  end
end

if Process.uid == 0
  uid = Etc.getpwnam(WH::Config.daemon.user).uid
  gid = Etc.getgrnam(WH::Config.daemon.group).gid
  Process::Sys.setuid(uid)
  Process::Sys.setgid(gid)

  if !test_drop
    puts "Failed to drop privs"
    exit
  end
end

Daemons.run(File.join(File.dirname(__FILE__),'workhorse.rb'), { 
  :app_name => 'workhorse', 
  :monitor => true, 
  :log_output => true, 
  :dir_mode => :system 
  })