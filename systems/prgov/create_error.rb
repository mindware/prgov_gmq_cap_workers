require '../lib/rest'
user = "***REMOVED***"
pass = "***REMOVED***"
# credentials via basic auth
url = "http://localhost:9000/v1/cap/transaction/"
first_name = 'Andrés' 
#ifirst_name = 'Andrés' * 100 
#first_name = '' 
last_name  = 'Colón'
#last_name  = 'Colón' * 100
#last_name  = ''
#mother_last_name = 'Pérez' 
#mother_last_name = 'Pérez' * 100 
mother_last_name = '' 
ssn =	'111-22-3333'
#ssn =	''
#ssn =	'111-22-3333-4444-5555-6666'
license = '123456789'
#license = '123456789' * 100
#license = ''
birth_date = '01/01/1982' 
#birth_date = '01/01/1982' * 100 
#birth_date = '' 
residency  = 'San Juan'
#residency  = 'San Juan' * 100
#residency  = ''
language    = 'spanish'
language    = 'french'
#language    = ''
IP = '192.168.1.2'
#IP = '192.168.1.2' * 100
#IP = '::1' # ipv6 
#IP = '::1' * 100 # ipv6 
#IP = ''
reason = 'Background check to join S.H.I.E.L.D.'
#reason = 'Background check to join S.H.I.E.L.D.' * 100
#reason = ''
#birth_place = "San Juan"
birth_place = "San Juan" * 100
email = "acolon@ogp.pr.gov"

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
