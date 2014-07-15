require '../lib/rest'

# PR.Gov transaction id:
tx_id = '0338ca35444694f18a'
user = "prgov"
pass = "***REMOVED***"
ip = '***REMOVED***'
http = 'https'
url = "#{http}://${ip}:#{pass}/#{url}"

# Grab the id from the params, otherwise us an id that may or may not exist.
if ARGV[0].to_s != ""
	id = ARGV[0]
	first_name = ARGV[1]
	last_name = ARGV[2]
	ssn	  = ARGV[3]
	license	  = ARGV[4]  
	birth_date = ARGV[5] 
	callback_url = ARGV[6] 	
end

# https://***REMOVED***/v1/api/rap/request?tx_id=0123456789123456&first_name=Andres&last_name=Colon&ssn=***REMOVED***&license=***REMOVED***&birth_date=***REMOVED***
payload = { 
	    "tx_id" => id,
	    "first_name" => first_name, 
	    "last_name" => last_name,
	    "ssn"	=> ssn,
	    "license"	=> license,
            "birth_date" => birth_date,
	    "callback_url" => callback_url
           }
method = "put"
type = "json"

a = Rest.new(url, user, pass, type, payload, method)
a.request
