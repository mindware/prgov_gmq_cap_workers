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

puts "\n\nStarting Script to clear old base64s certs from memory\n\n"

# values = GMQ::Workers::Store.db.get("gmq:cap:tx:PRCAP1155568347147470178")
#puts values

keys = []
GMQ::Workers::Store.db.scan_each(:match => "gmq:cap:tx:PRCAP*") {|key|
	# append the key but strip the specific redis namespace
	key = key.to_s.gsub("gmq:cap:tx:", "")
	keys << key
}

puts "Found a total of #{keys.length} transactions in the storage."

cleared = 0
errors = 0

keys.each do |key|
	begin
		tx = GMQ::Workers::Transaction.find key
	rescue Exception => e
		puts "Error #{e} while processing #{key}. Continuing."
		errors += 1
		# skip this one
		next
	end
	if(tx.state.to_s == "done_mailing_certificate")
		cleared += 1
		tx.certificate_base64 = nil
		tx.save
		puts "Processing #{tx.id} from #{tx.updated_at}"
	end
end

puts "Found a total of #{cleared} transactions that had completed but "+
"whose certificate was still in memory, wasting space. We cleared them "+
"from a total of #{keys.length}."
puts "Additionally, we now know that #{(keys.length - cleared)} transactions "+
"have not resulted in certificates being sent yet."
puts "We encountered #{errors} errors."
puts "Done."
