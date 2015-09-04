require '../lib/rest'
require 'base64'

user = "user"
pass = "password"

url = "http://localhost:9000/v1/cap/transaction/certificate_ready"
method = "put"
type = "json"

file = File.open("./sample/sagan.jpg", "rb")
contents = file.read
cert64 = Base64.strict_encode64(contents)
id = '1e29234ee0c84921adec08fbe5980162'
#id = 'falseid'
#id = ''
#cert64 = 'invalid base64'
cert64 = ''
#payload = { "id" => id,
#            "certificate_base64" => cert64 }
#payload = 'false'
payload = { "id" => id }

a = Rest.new(url, user, pass, type, payload, method)
a.request
