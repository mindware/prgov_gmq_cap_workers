#!/usr/bin/env ruby
# First, fix the paths so that everything under this directory
# is in the ruby path. This way we don't have to include relative filepaths
$: << File.expand_path(File.dirname(__FILE__) +"/")

puts "URL: #{File.expand_path(File.dirname(__FILE__) +"/")}"

Dir.chdir File.expand_path(File.dirname(__FILE__) +"/")

require '../lib/rest'
require 'resque'
require 'resque-scheduler'
require 'resque-retry'
require 'dotenv'

require 'csv'

# Load our environment variables from the hidden '.env' file in this projects root folder.
Dotenv.load

require 'app/helpers/config'
require 'app/helpers/store'

# Setup the configuration
GMQ::Workers::Config.check

# Resque accepts an existing redis connection, so let's
# make it use ours.
# TODO: update this later so that resque gains db reconnection capabilities
Resque.redis = GMQ::Workers::Store.db

# require our jobs & application code.
# We'll require all existing workers in the core/workers directory
# These are used both by the Resque workers as well as the Resque-web
Dir["app/core/workers/*.rb"].each {|file| require file }

state = ""
if(ARGV.length == 0)
	puts "Enter the state to search for (string only we'll conver to symbol): "
	state = $stdin.gets
	if(state.length > 0)
			
	end
else
	state = ARGV[0]
end

keys = [] 
GMQ::Workers::Store.db.scan_each(:match => "gmq:cap:tx:PRCAP*") {|key| 
	# append the key but strip the specific redis namespace
	key = key.to_s.gsub("gmq:cap:tx:", "") 
	keys << key
}

puts "Found a total of #{keys.length} transactions in the storage."

waiting = 0

sorted = [] 

keys.each do |key|
	begin
		tx = GMQ::Workers::Transaction.find key 
	rescue Exception => e
		puts "Error #{e} while processing #{key}. Cannot continue."
		exit
	end
	if(tx.state.to_s == "waiting_for_sijc_to_generate_cert")
		waiting += 1
		# puts "#{tx.id} - waiting for SIJC since #{tx.updated_at}" 
		sorted << { :id => tx.id, :updated_at => tx.updated_at } 
	end
end

keys = nil 


sorted.sort_by! {|tx| tx[:updated_at] }

sorted.each do |key|
	puts "#{key[:id]} - waiting for SIJC since #{key[:updated_at]}" 
end

puts "Found #{waiting} waiting out of #{sorted.length}"  
puts "Done."
