#!/usr/bin/env ruby
$LOAD_PATH.unshift( File.join(File.dirname(__FILE__),'lib') );

require 'rubygems'
require 'workhorse'

trap("INT") { WH.interrupted = true }
trap("TERM") { WH.interrupted = true }

WH.run
WH.terminate