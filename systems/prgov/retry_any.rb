# First, fix the paths so that everything under this directory
# is in the ruby path. This way we don't have to include relative filepaths
$: << File.expand_path(File.dirname(__FILE__) +"/")

puts "URL: #{File.expand_path(File.dirname(__FILE__) +"/")}"

Dir.chdir File.expand_path(File.dirname(__FILE__) +"/")

require 'time'
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

# This is the recommended way to configure Resque but
# it errors out. So we use what's above.
# Resque.configure do |configuration|
#   configuration.redis = GMQ::Workers::Store.db
# end

# require our jobs & application code.
# We'll require all existing workers in the core/workers directory
# These are used both by the Resque workers as well as the Resque-web
Dir["app/core/workers/*.rb"].each {|file| require file }

puts "\n\nStarting Script\n\n"

#values = GMQ::Workers::Store.db.get("gmq:cap:tx:PRCAP1155568347147470178")
#puts values

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
		today = Time.now
		tx_date = Time.parse tx.updated_at.to_s 
	
		# if this is a transaction from today less than one hour ago 
		if(false and today.month == tx_date.month and today.day == tx_date.day and today.year == tx_date.year and today.hour == tx_date.hour)
			# skip it
			puts "Skipping #{tx.id} as it was last updated today. "+
			     "less than an hour ago."
			next 
		end

		waiting += 1
		# sleep one second before re-queing to do this 
		# in a gentler way. We have about 30 workers per server, so 
		# processing 5 jobs every 5 seconds is fine. 
		sleep 1
		# puts "#{tx.id} - waiting for SIJC since #{tx.updated_at}" 
		sorted << { :id => tx.id, :updated_at => tx.updated_at } 
		result = tx.requeue_rapsheet_job
		puts "Requeuing #{tx.id} - from #{tx.updated_at} - #{result}" 
	end
end

puts "Found #{waiting} waiting out of #{keys.length}, and re-enqueued all of them."  
puts "Done."
