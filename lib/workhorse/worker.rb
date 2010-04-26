require 'rubygems'
require 'eventmachine'

class Worker
  include EM::Deferrable

  def heavy_lifting
    30.times do |i|
      puts "Lifted #{i}"
      sleep 0.1
    end
    set_deferred_status :succeeded
  end
  
  def heavy_pulling
    60.times do |i|
      puts "Pulled #{i}"
      sleep 0.1
    end
    set_deferred_status :succeeded
  end
end