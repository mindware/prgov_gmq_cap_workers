require '../lib/rest'

require 'base64'

user = "***REMOVED***"
pass = "***REMOVED***"
id = '1e29234ee0c84921adec08fbe5980162'
url = "http://localhost:9000/v1/cap/transaction/review_complete"

# I tested each of the following commented codes, to try to force
# an error. They each returned proper errors. One by one, until
# all were fixed. Good to go.
anpe_action_id      = "030"
#anpe_action_id      = ""
#anpe_transaction_id = "anpe12345"
anpe_transaction_id = ""
approval_date       = Time.now.utc
#approval_date       = "invalid date"
decision            = "100"
#decision            = "1001"

payload = {
              "id" => id,
              "decision_code" => decision,
#              "analyst_internal_status_id" => anpe_action_id,
              "analyst_transaction_id" => anpe_transaction_id,
              "analyst_approval_datetime" => approval_date
          }
method = "put"
type = "json"

a = Rest.new(url, user, pass, type, payload, method)
a.request
