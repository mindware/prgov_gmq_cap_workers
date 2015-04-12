require '../lib/rest'

# PR.Gov transaction id:
tx_id = '0338ca35444694f18a'
user = ENV['SIJC_RCI_USER']
pass = ENV['SIJC_RCI_PASSWORD']
#ip = '***REMOVED***'
ip = ENV['SIJC_IP']
#port = ''
port = "#{ENV['SIJC_PORT']}"
#http = 'https'
http = ENV['SIJC_PROTOCOL']
#url = "#{http}://#{user}:#{pass}@#{ip}"
version = "/v1/api/rap/request?"
url = "#{http}://#{ip}#{port}#{version}"

# Grab the id from the params, otherwise us an id that may or may not exist.
# Length is 8 if a middle name was included and mother maiden name
if ARGV[0].to_s != "" and ARGV.length == 9 
	id = ARGV[0]
	first_name = ARGV[1]
	middle_name = ARGV[2]
	last_name = ARGV[3]
	mother_last_name = ARGV[4]
	ssn	  = ARGV[5]
	license	  = ARGV[6]  
	birth_date = ARGV[7] 
	callback_url = ARGV[8] 	
else 
# if no middle name was included
        id = ARGV[0]
        first_name = ARGV[1]
        middle_name = ""
        last_name = ARGV[2]
        mother_last_name = ARGV[3]
        ssn       = ARGV[4]
        license   = ARGV[5]
        birth_date = ARGV[6]
        callback_url = ARGV[7]
end

payload = { 
	    "tx_id" => id,
	    "first_name" => first_name, 
	    "middle_name" => middle_name, 
	    "last_name" => last_name,
	    "ssn"	=> ssn,
	    "license"	=> license,
            "birth_date" => birth_date,
	    "callback_url" => callback_url
           }
method = "put"
type = "json"


method = 'get'

if(method == "get")
	payload.each do |key, value|
		url << "&#{key}=#{value}"
	end
end
a = Rest.new(url, user, pass, type, payload, method)
a.request
