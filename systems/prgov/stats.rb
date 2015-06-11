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

values = GMQ::Workers::Store.db.get("gmq:cap:tx:PRCAP1155568347147470178")
#puts values

keys = [] 
GMQ::Workers::Store.db.scan_each(:match => "gmq:cap:tx:PRCAP*") {|key| 
	# append the key but strip the specific redis namespace
	key = key.to_s.gsub("gmq:cap:tx:", "") 
	keys << key
}

puts "Found a total of #{keys.length} transactions in the storage."

certificate = 0
error = 0
error_user_identified = 0
error_done = 0
error_not_done = 0
error_user_not_identified = 0
unknown = 0
unknown_types = {} 
keys.each do |key|
	begin
		tx = GMQ::Workers::Transaction.find key 
	rescue Exception => e
		puts "Error #{e} while processing #{key}. Cannot continue."
		exit
	end
	if(tx.state.to_s == "done_mailing_certificate")
		certificate += 1
		# puts "#{tx.id} - waiting for SIJC since #{tx.updated_at}" 
	elsif (tx.state.to_s.include? "error" or tx.state.to_s.include? "fail")
		if(tx.identity_validated) 
			error_user_identified += 1
		else
			error_user_not_identified += 1
		end
	
		if(tx.status == "done" or tx.status == "completed")
			error_done += 1
		else
			error_not_done += 1
		end
		error += 1
	else
		if unknown_types.keys.include? tx.state.to_s
			unknown_types[tx.state.to_s] += 1	
		else
			unknown_types[tx.state.to_s] = 0
		end
		unknown += 1
	end
end

puts "Hay un total de #{keys.length} transacciones en el sistema."  
puts "Un total de #{error + certificate} se completaron exitosamente."
puts "Se han emitido #{certificate} certificatados positivos y negativos "+
     "de esas #{keys.length} transacciones."  
puts "Hemos encontrado #{error} transacciones con errores de las "+
     "#{keys.length}."  
puts "De esas #{error} transacciones con error, #{error_done} fueron "+
     "transacciones que completaron exitosamente, y #{error_not_done} aun "+
     "no han completado." 
puts "De esas transacciones #{error_user_identified} se les habia "+
     "identificado la identidad al ciudadano, y #{error_user_not_identified} "+
     "no se les identificó."

# if any unknown errors were found
if(unknown_types.keys.length > 0)
	print "Encontramos #{unknown} transacciones de #{keys.length} con "+
	"las siguientes caracteristicas: " 
	unknown_types.each do |key, value|
		print "#{value} of #{key}"		
	end	
	puts "."
end
puts "Done."
