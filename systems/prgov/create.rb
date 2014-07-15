require '../lib/rest'
user = "***REMOVED***"
pass = "***REMOVED***"
# credentials via basic auth
url = "http://localhost:9000/v1/cap/transaction/"
first_name = 'Andrés' 
last_name  = 'Colón'
mother_last_name = 'Pérez' 
ssn =	'111-22-3333'
license = '123456789'
birth_date = '01/01/1982' 
residency  = 'San Juan'
IP = '192.168.1.2'
reason = 'Background check to join S.H.I.E.L.D.'
birth_place = "San Juan"
email = "acolon@ogp.pr.gov"
# Test it in english and spanish. Comment last one to try the other.
language = 'english'
language = 'spanish'

payload = { 
		:first_name => first_name,
		:last_name  => last_name,
		:mother_last_name => mother_last_name,
		:ssn	=> ssn,
		:license_number => license,
		:birth_date => birth_date,
		:residency  => residency,
		:IP	    => IP,
		:reason	    => reason,
		:birth_place=> birth_place,
		:email	    => email,
		:language   => language
	 }
method = "post"
type = "json"

a = Rest.new(url, user, pass, type, payload, method)
a.request
