require 'htmlentities'
# The transaction class is the Object that represents a transaction as it is
# stored in the database. It uses the Base class, which holds the basic
# methods for representing the way keys are stored in the data Store (db).
#
# It allows for finding and creating transactions. It uses helper methods
# from the Validations module for both instance and class methods, to validate
# user input. It has whitelists, per API action, that determine which user
# parameters are taken into consdieration, while the rest are ignored. As such
# parameters that are sneaked into an action, where they are not expected, are
# immediately dropped (such as creating a new transaction and appending the
# certificate, or modifying the state).
#
# The transactoin uses Act As State Machine to create a set of states
# to track where a transaction is and where it is going next based on a
# predetermined workflow.
#
# Version v1:
# Andrés Colón Pérez
# Chief Technology Officer, Chief Security Officer
# Office of the CIO (Giancarlo Gonzalez)
# Government of Puerto Rico
# May - 2014
#
require 'app/models/base'
require 'app/helpers/validations'
module GMQ
  module Workers
    class Transaction < GMQ::Workers::Base
      # We use both class and instance methods
      extend Validations
      include Validations
      include LibraryHelper

      # A note on the expiration of transactions:
      # Transaction expiration means expiration from the DB
      # as in, disappearing from the system entirely. The system has been
      # designed to expire Transactions after time. The backup strategy
      # implemented by the system administrators will determine the longrevity
      # of the data in an alternate medium, and such will be the strategy for
      # compliance for audits that span a period of time longer than the
      # maximum retention of this system. An alternate archival strategy
      # could be implemented where transactions are stored in an alternate
      # database for inspection, but this is left as an exercise for a future
      # version of the system.
      #
      # Transaction Expiration vs Certificate Expiration:
      # Transaction expiration shouldn't be confused with that of a certificate.
      # A certificate could be invalidated by the PR.Gov's validation system
      # even if the transaction still hasn't expired. For example, say it has
      # been determined that a certificate shouldn't be valid after 1 month,
      # in such a case PR.Gov's validation mechanism could check the transaction
      # approval date and see if it has already reached its certificate
      # expiration limit. However, the Transaction expiration might still not
      # have come into effect, and thus, we could have the ability to peer into
      # the transaction for administrative and audit purposes long after the
      # certificate has already expired.
      #
      # Important Hint for Backup Restoration and Transaction Expiration:
      #
      # Administrators, "Hear ye, hear ye!". This is important.
      # Transaction expiration is going to be performed at the Storage level.
      # This means if you ever manually restore a backup, in order to peer at
      # old transactions, such as for an audit, it is important that the time
      # of the server be modified to the time of the backup, otherwise, the
      # storage system will see the time difference (Redis) and determine that
      # the transactions expiration time has come up, and immediately expire
      # data. This is because the storage mechanism that performs expiration of
      # keys does it using the current time. If you restore data from the past
      # into a server whose datetime is configured to the present or future,
      # expiration will come into effect for anythign that should be expired.
      # This would have the effect that you know you're restoring data, but
      # as soon as you peek at it, it's gone (expired).
      #
      # If you set MONTHS_TO_EXPIRATION_OF_TRANSACTION to 0, new transactions
      # will never expire. (Hint: that could fill up the database store quickly
      # leaving the server without RAM, it is **not** recommended, be very
      # careful). Only do it if you know what you're doing, or are eager to get
      # fired. Seriously, don't do it.
      #
      # By default, we recomend 1 or three months to keep the transaction in the
      # system for inspection after it has become idle. Once expired, it's
      # really gone. Redis allows for a maximum of 25 years (25 * 12), but
      # again, don't try it as the system will quickly store everything in ram
      # and run out of it. If a transaction is touched (ie, updated in anyway)
      # its time to live (TTL) will reset.
      #
      # As discussed in several meetings with the PRPD and DOJ, the source of
      # truth for all transaction requests is RCI. It was agreed that
      # PR.gov at minimum will hold transactions in memory for one month.
      # Beyond that it is optional for PR.gov to keep data in hot storage
      # Any data that must be fetched must be retrieved in cold backups
      # if they exceed this date. For this reason, PR.gov sends meta-data
      # to RCI about transactions, and stores information for the following
      # months in hot-storage (cold-storage being subject to OGP retention
      # policies):
      MONTHS_TO_EXPIRATION_OF_TRANSACTION = 3

      # The expiration is going to be Z months, in seconds.
      # Time To Live - Math:
      # 604800 seconds in a week X 4 weeks = 1 month in seconds
      # We multiply this amount for the Z amount of months that a transaction
      # can last before expiring.
      EXPIRATION = (604800 * 4) * MONTHS_TO_EXPIRATION_OF_TRANSACTION

      LAST_TRANSACTIONS_TO_KEEP_IN_CACHE = 5000

      ######################################################
      # A transaction generally consists of the following: #
      ######################################################

      # If you add an attribute, update the initialize method and to_hash method
      attr_accessor :id,     # our transaction id
                    :numeric_id,           # A numeric id
                    :email,                # user email
                    :ssn,                  # social security number
                    :passport,             # passport number
                    :license_number,       # valid dtop identification
                    :first_name,           # user's first name
                    :middle_name,          # user's middle name
                    :last_name,            # user's last name
                    :mother_last_name,     # user's maternal last name
                    :residency,            # place of residency
                    :birth_date,           # the date of birth
                    :reason,               # the user's reason for the request
                    :IP,                   # originating IP of the requester as
                                           # claimed/forwarded by client system
                    :system_address,       # the IP of the client system that
                                           # talks to the API
                    :language,             # User specified language
                    :status,               # the status pending proceessing etc
                    :state,                # the state of the State Machine
                    :history,              # A history of all actions performed
                    :location,             # the system that was last assigned
                                           # the Tx to
                    :created_at,           # creation date
                    :updated_at,           # last update
                    :created_by,           # the user that created this
                    :certificate_base64,   # The base64 certificate -
                                           # currently just a flag that lets us
                                           # know it was already generated so
                                           # we can pick it up in SIJC.
                                           # PR.Gov is no longer storing
                                           # certificates, when SIJC calls back
                                           # after generation. Due to a storage
                                           # issue related to RAM and Redis.
                                           # Instead, workers pick up the
                                           # certificate as they're ready to
                                           # email a certificate.
                    :analyst_fullname,     # The fullname of the analyst at
                                           # PRPD that authorized this request.
                    :analyst_id,           # The user id of the analyst at PRPD
                                           # that authorized this request
                                           # through their System.
                    :analyst_approval_datetime, # The exact date and time in
                                                # which the user approved this
                                                # action. This must correspond
                                                # with the tiemstamps in the
                                                # PRPD’s analyst system, such
                                                # RCI, so that in the event of
                                                # an audit correlation is
                                                # possible.
                    :analyst_transaction_id,    # The internal id of the
                                                # matching request in the
                                                # Analyst System. This id
                                                # can be used
                                                # in case of an audit.
                    :analyst_internal_status_id,# The matching internal
                                                # decision code id of the
                                                # system used by the analysts.
                    :decision_code,             # The decision of the analyst at
                                                # PRPD of what must be done with
                                                # transaction after their
                                                # exhaustive manual review
                                                # process. The following
                                                # decisions are supplied by the
                                                # PRPD system login only:
                                                # 100 - Issue Negative Cert
                                                # 200 - Positive Certificate
                    :identity_validated,        # This tells us if the citizen
                                                # was identified in a Gov db
                                                # nil: if nothing done yet
                                                # true: validated
                                                # false: failed validation
                    :emit_certificate_type,     # The type of certificate we
                                                # have been told we are to
                                                # receive and send:
                                                # "positive" - a positive cert
                                                # "negative" - a negative cert
                                                # This is set not only by the
                                                # decision_code when a fuzzy
                                                # result requires an PRPD
                                                # analyst, but also by
                                                # RCI when it determines
                                                # it has enough data to make a
                                                # decision.
                    :certificate_path,          # The temporary file path to the
                                                # certificate in disk.
                    :error_count,               # A total count of generic
                                                # errors that can be counted,
                                                # relating to the management of
                                                # this transaction, when this
                                                # transaction is accessible to
                                                # other systems, such as gmq
                                                # workers validating against rci.
                    :rci_error_count,           # Rci connection errors.
                    :rci_error_date,            # Last date that had an rci
                                                # connection error
                    :email_error_count,         # Email connection errors.
                    :email_error_date,          # Last date of email error.
                    :last_error_type,           # Exception name of Last error
                    :last_error_date            # Date of last error.

      # Newly created Transactions
      def self.create(params)

          # The following parameters are allowed to be retrieved
          # everything else will be discarded from the user params
          # by the validate_transaction_creation_parameters() method
          whitelist = ["email", "ssn", "passport", "license_number",
          "first_name", "middle_name", "last_name", "mother_last_name",
          "residency", "birth_date", "IP", "reason", "system_address",
          "created_by", "language" ]


          # Instead of trusting user input, let's extract *exactly* the
          # values from the params hash. This way, additional values
          # that may have been sneaked inside the params hash are ignored
          # safely and never reach the Store. This is done by the validate
          # method:
          # validate all the parameters in the incoming payload
          # throws valid errors if any are detected
          # it will remove non-whitelisted params from the parameters.
          params = validate_transaction_creation_parameters(params, whitelist)

          tx = self.new.setup(params)

          # Add important system defined parameters here:
          tx.id                  = generate_key()
          tx.created_at          = Time.now
          tx.status              = "received"
          tx.location            = "PR.gov GMQ"
          tx.state               = :new

          tx.error_count         = 0
          tx.rci_error_count     = 0
          tx.rci_error_date      = ""
          tx.email_error_count   = 0
          tx.email_error_date    = ""
          tx.last_error_type     = ""
          tx.last_error_date     = ""

          # Pending stuff that we've yet to develop:
          # tx["history"]           = {
          #                             "received" => {
          #                                             "date" => Time.now
          #                                           }
          #                           }
          # attribute :action, Hash
          # attribute :action_id, Integer
          # attribute :action_description, String
          return tx
      end

      # Loads values from a hash into this object
      # This
      def setup(params, action=nil)
          if params.is_a? Hash
              self.id                         = params["id"]
              self.email                      = params["email"]
              self.ssn                        = params["ssn"]
              self.passport                   = params["passport"]
              self.license_number             = params["license_number"]
              self.first_name                 = params["first_name"]
              self.middle_name                = params["middle_name"]
              self.last_name                  = params["last_name"]
              self.mother_last_name           = params["mother_last_name"]
              self.residency                  = params["residency"]
              self.birth_date                 = params["birth_date"]
              self.reason                     = params["reason"]
              self.IP                         = params["IP"]
              self.system_address             = params["system_address"]
              self.language                   = params["language"]
              self.status                     = params["status"]
              self.location                   = params["location"]
              self.state                      = params["state"]
              self.created_at                 = params["created_at"]
              self.created_by                 = params["created_by"]
              self.updated_at                 = params["updated_at"]
              self.certificate_base64         = params["certificate_base64"]
              self.analyst_fullname           = params["analyst_fullname"]
              self.analyst_id                 = params["analyst_id"]
              self.analyst_approval_datetime  = params["analyst_approval_datetime"]
              self.analyst_transaction_id     = params["analyst_transaction_id"]
              self.analyst_internal_status_id = params["analyst_internal_status_id"]
              self.decision_code              = params["decision_code"]
              self.identity_validated         = params["identity_validated"]
              self.emit_certificate_type      = params["emit_certificate_type"]
              self.certificate_path           = params["certificate_path"]
              self.error_count                = params["error_count"]
              self.rci_error_count            = params["rci_error_count"]
              self.rci_error_date             = params["rci_error_date"]
              self.email_error_count          = params["email_error_count"]
              self.email_error_date           = params["email_error_date"]
              self.last_error_type            = params["last_error_type"]
              self.last_error_date            = params["last_error_date"]
              self.numeric_id                 = params["numeric_id"]
          end
          return self
      end

      def initialize
          super
          @id = nil
          @email = nil
          @ssn = nil
          @passport = nil
          @license_number = nil
          @first_name = nil
          @middle_name = nil
          @last_name = nil
          @mother_last_name = nil
          @IP = nil
          @birth_date = nil
          @residency = nil
          @reason = nil
          @language = nil
          @location = nil
          @history = nil
          @state = nil
          @status = nil
          @system_address = nil
          @created_at = nil
          @updated_at = nil
          @created_by = nil
          @certificate_base64 = false
          @analyst_fullname = nil
          @analyst_id = nil
          @analyst_approval_datetime = nil
          @analyst_transaction_id = nil
          @analyst_internal_status_id = nil
          @decision_code = nil
          @identity_validated = nil
          @emit_certificate_type = nil
          @certificate_path = nil
          @error_count = nil
          @rci_error_count = nil
          @rci_error_date = nil
          @email_error_count = nil
          @email_error_date = nil
          @last_error_type = nil
          @last_error_date = nil
          @numeric_id = nil
      end

      def to_hash
        # Grab all global global variables in this Object, and turn it into
        # a hash. Should any odd global variable be defined in this object for
        # any other reason than to return the information the API,
        # such as for configuration, that variable will be in this hash, however
        # will not get exposed, due to the Transaction Entity, which is what
        # determines what is exposed via the API. That said, at this time we
        # dont have a single variable that's used for anything other than
        # presenting to the user relevant information. After we return this
        # it'll be filtered by the Transaction Entity.
        # Using this method saves us the work of having to define a to_hash
        # method with every single attribute, everytime it's updated, such as:
        # {
        #   "transaction" => {
        #         "id"               => "#{@id}",
        #         "email"            => "#{@email}",
        #         "ssn"              => "#{@ssn}",
        #           .
        #           .
        #           etc  }
        # }
        # So here we go, let's do some meta-programming magic:
        h =  self.instance_variables.each_with_object({}) { |var,hash|
             hash[var.to_s.delete("@")] = self.instance_variable_get(var) }
        # add any values that aren't variables, but are the result of methods:
        return h
      end

      # Turns a hash into a json object
      def to_json
        to_hash.to_json
      end

      # just an alias in order to have an instance method available
      def ip
        self.IP
      end

      # error count for current state
      def self.current_error_count(id, str=false)
        if(!str)
          return Store.db.get("#{db_id(id)}:errors:current_count")
        elsif(str == "increment")
          return Store.db.incr("#{db_id(id)}:errors:current_count")
        elsif(str == "decrement")
          return Store.db.decr("#{db_id(id)}:errors:current_count")
        elsif(str == "reset")
          return Store.db.set("#{db_id(id)}:errors:current_count", 0)
        else # if anything else is sent:
          false
        end
      end

      def current_error_count
          count = Transaction.current_error_count(self.id)
          count.nil? ? 0 : count.to_i
      end

      # Sets the key prefix for the database.
      def self.db_prefix
        "tx"
      end

      def db_cache_info
        self.id
      end

      # Checks ttl for an id, after a transaction is saved
      # it stores an expiration time.
      # description:
      # gets ttl count for current item
      def ttl()
          Store.db.ttl(db_id)
      end

      def expires
          time_from_now(ttl)
      end


      # Tries to find and setup a transaction object by id.
      def self.find(id)
          # if the record wasn't found
          false if id.nil?

          # Do a multi / exec query:
          # Store.db.multi do
            # find the transaction by the id
            # get the total error count for this item from the error key
            # error_count = self.current_error_count(id)
          # end

          if(!data = Store.db.get(db_id(id)))
            raise TransactionNotFound
          else
            begin
              # grab the JSON from this transaction id
              data = JSON.parse(data)
              # set it up into this object's variables
            rescue Exception => e
              raise InvalidNonJsonRecord
            end

            # If no error count found in the db, return 0, else, return count
            # data["current_error_count"] = (error_count.nil? ? 0 : error_count)
            # data["current_error_count"] = (error_count.nil? ? 0 : error_count)
            # Here we instantiate a Transaction object and set it up with data
            return Transaction.new.setup(data)
          end
      end

      # this needs to be a class method, we dont want to
      # accidentally overwrite transaction values.
      def self.validate_request(params)
          # incase someone sent the id as tx_id
          params["id"] = params["tx_id"] if !params["tx_id"].nil?

          # The following parameters are allowed to be retrieved
          # everything else will be discarded from the user params
          # by the validation method
          whitelist = [ "id", "ssn", "passport", "IP" ]

          # Instead of trusting user input, let's extract *exactly* the
          # values from the params hash. This way, additional values
          # that may have been sneaked inside the params hash are ignored
          # safely and never reach the Store. This is done by the validate
          # method:
          # validate all the parameters in the incoming payload
          # throws valid errors if any are detected
          # it will remove non-whitelisted params from the parameters.
          params = validate_transaction_validation_parameters(params, whitelist)

          params["request_id"] = generate_random_id()
          self.job_request_certificate_validation(params)
      end

      # Class method that returns a list of the last transactions in the system
      # TODO: check what this returns when db is empty.
      def self.last_transactions
          Store.db.lrange(Transaction.db_list, 0, -1)
      end

      # Generates a full name based on aggregating transaction citizen name data
      def full_name
          name = first_name.strip # required
          name << " #{middle_name.strip}" if !middle_name.nil?
          name << " #{last_name.strip}" # required
          name << " #{mother_last_name.strip}" if !mother_last_name.nil?

          # capitalize each word and return the capitalized version
          name.split.map(&:capitalize).join(' ')
      end


      # This method returns a proper Resque Job JSON.
      # Instead of using the official Resque enqueue method, which uses its
      # own database connection, we directly talk to Redis and place a job
      # JSON, built by this method, for Resque to grab in the Transaction's save
      # method. We read Resque's source-code and identified the standard for
      # placing Jobs in the queue (File lib/resque/job.rb, line 38 and
      # File lib/resque.rb, line 56). Essentially what Resque does is this:
      # Resque.push(queue, :class => klass.to_s, :args => args)
      # Translates to: redis.rpush "queue:#{queue}", encode(item).
      # Basically it is this: redis.rpush queue_name, json_payload
      # where queue_name is "resque:queue:#{queue_name}" and the json
      # payload is a job in the form of:
      # {:class => klass.to_s, :args => args}.to_json
      #
      # This job_data method performs the creation of that proper json job
      # payload. It generates generates a hash that includes the
      # worker that will be instantiated by the Resque and the id it will
      # process.
      def job_notification_data()
        # "{ \"class\":\"RequestWorker\", \"args\":[\"#{db_id}\"] }"
        # Here we create a hash of what the Resque system will expect in
        # the redis queue under resque:queue:prgov_cap.
        # Note: don't use single quotes for string values on JSON.
        # Resque expects a JSON so we will create a ruby hash, and safely
        # turn it to JSON.
        # There's no need to send the entiret tx object to the worker, we just
        # send it the id and it'll fetch it and work with it, using the latest
        # information in the db.
        # Finally: the information the job_data sends to resque is
        # message = Config.all["messages"]["initial_confirmation"]

        if language == "english"
          subject = "PR.Gov Good Standing Certificate Request"
          message = "Thank you for using PR.Gov's online services. You are "+
                    "receiving this email because we have received a "+
                    "request to validate submission information for a "+
                    "Good Standing Certificate for '#{full_name}'.\n\n"+
                    "The transaction number is:\n'#{id}'.\n\n"+
                    "The information is being verified against multiple systems "+
                    "and data sources, including the Puerto Rico Police "+
                    "Department and the Criminal Justice Information Division.\n\n"+
                    "As the validation progresses, you will be receiving "+
                    "additional emails from us.\n\n"+
                    "If you did not requested this "+
                    "certificate and believe it to be an error, we ask that you "+
                    "ignore and delete this and any related messages."
        else
          #spanish
          subject = "Solicitud de Certificado de Antecedentes Penales de PR.Gov"
          message = "Gracias por utilizar los servicios de PR.Gov. Está "+
                    "recibiendo este correo por que hemos recibido una "+
                    "solicitud de validación de información para un "+
                    "certificado de Antecedente Penal de la Policía "+
                    "de Puerto Rico para "+
                    "'#{full_name}'. Hemos comenzado el proceso de validación "+
                    "de la solicitud.\n\n"+
                    "El número de la transacción es:\n'#{id}'.\n\n"+
                    "En estos momentos la información de la solicitud "+
                    "está siendo validada con los sistemas de Policia de "+
                    "Puerto Rico, el Sistema Integrado de Justicia Criminal del "+
                    "Departamento de Justicia y otras agencias de ley y orden.\n\n"+
                    "Una vez completada la revisión estará "+
                    "recibiendo otro comunicado de nuestra parte a esta dirección.\n\n"+
                    "Si entiende que esta solicitud fue en error, por favor "+
                    "ignore y elimine este, y cualquier correo relacionado al "+
                    "mismo."
        end

        html_message = "<html><body>"
        html_message << HTMLEntities.new.encode(message, :named).gsub("\n", "<br>")
        html_message << "</body></html>"

        { "class" => "GMQ::Workers::EmailWorker",
                     "args" => [{
                                 "id" => "#{id}",
                                 "queued_at" => "#{Time.now}",
				                         "text" => message,
                                 "subject" => subject,
                                 "html" => html_message,
                                 "request_rapsheet" => true,
                                }]
        }.to_json
      end

      def job_rapsheet_validation_data(mute = false)
        # Here we create a hash of what the Resque system will expect in
        # the redis queue under resque:queue:prgov_cap.
        # Note: don't use single quotes for string values on JSON.
        { "class" => "GMQ::Workers::RapsheetWorker",
                     "args" => [{
                                 "id" => "#{id}",
                                 "queued_at" => "#{Time.now}",
                                 "mute" => "#{mute}"
                                }]
        }.to_json
      end

      # Retrieve a certificate that has already been generated
      # in the recent past in RCI.
      # If the transaction exists we will receive a base64 output.
      # Optional:
      # If we provide a callback_url as true, this will not only fetch the certificate
      # but force RCI to perform a callback to the GMQ of certificate_ready callback url specified
      # in the RetrieveWorker of the GMQ,
      # which basically will execute the final step of a transaction
      # request, forcing the process to ocurr, including receiving the cert at the GMQ
      # API, creating the PDF, and sending it to the user via email.
      def job_certificate_retrieve_data(callback_url=false)
        # Here we create a hash of what the Resque system will expect in
        # the redis queue under resque:queue:prgov_cap.
        # Note: don't use single quotes for string values on JSON.
        { "class" => "GMQ::Workers::RapsheetRetrieveWorker",
                     "args" => [{
                                 "id" => "#{id}",
                                 "queued_at" => "#{Time.now}",
				 "callback_url" => callback_url
                                }]
        }.to_json
      end


      def job_generate_negative_certificate_data
        # Here we create a hash of what the Resque system will expect in
        # the redis queue under resque:queue:prgov_cap.
        # Note: don't use single quotes for string values on JSON.
        { "class" => "GMQ::Workers::CreateCertificate",
                     "args" => [{
                                 "id" => "#{id}",
                                 "queued_at" => "#{Time.now}"
                                }]
        }.to_json
      end

      # class method for transaction validation.
      # Here we request the transaction be validated against
      # the remote system that is the source of all truths regarding
      # certificates: RCI.
      def self.job_request_certificate_validation(params)
        # Here we create a hash of what the Resque system will expect in
        # the redis queue under resque:queue:prgov_cap.
        # Note: don't use single quotes for string values on JSON.
        { "class" => "GMQ::Workers::CAPValidationWorker",
                     "args" => [{
                                 "id" => params["id"],
                                 "tx_id" => "#{params["tx_id"]}",
                                 "ssn" => "#{params["ssn"]}",
                                 "passport" => "#{params["passport"]}",
                                 "IP" => "#{params["IP"]}",
                                 "queued_at" => "#{Time.now}"
                                }]
        }.to_json
      end

      # This method returns the name of the queue we're going to use
      def queue_pending
        "resque:queue:prgov_cap"
      end


      # Remove an item from recent transactions list
      def self.remove_id_from_last_list(id)
        Store.db.lrem(db_list, 0, id)
      end

      # Deletes this transaction
      def destroy
        Store.db.del(db_id)
      end

      # The public method that allows this instance to be saved to the
      # database.
      def save
        # Update the updated_at timestamp.
        # If we had servers in multiple time zones, we'd want
        # to use utc in the next line. This might be important
        # if we go cloud in multiple availability zones, this
        # way time is consistent across zones.
        # self.updated_at                 = Time.now.utc
        self.updated_at                 = Time.now

        # Flag that will determine if this is the first time we save.
        first_save = false
        # if this is our first time saving this transaction
        if(@state == :new)
          @state = :started
          first_save = true
          # if new, grab a numeric id and assign it to this object
          if(@numeric_id == nil)
             @numeric_id = Store.db.incr("#{Transaction.db_global_prefix}:numeric_id_count")
          end
        end

        # Now lets convert the transaction object to a json. Note:
        # We have to retrieve this here, incase we ever need values here
        # from the Store. If we do it inside the multi or pipelined
        # we won't have those values availble when building the json
        # and all we'll have is a Redis::Future object. By doing
        # the following to_json call here, we would've retrieved the data
        # needed before the save, properly.
        json = self.to_json
        # do a pipeline command, executing all commands in an atomic fashion.
        # inform the pipelined save if this is the first time we're saving the
        # transaction, so that proper jobs may be enqueued.
        pipelined_save(json, first_save)
        # puts caller
        if Config.display_hints
          debug "#{"Hint".green}: View the transaction data in Redis using: GET #{db_id}\n"+
                "#{"Hint".green}: View the last #{LAST_TRANSACTIONS_TO_KEEP_IN_CACHE} transactions using: "+
                "LRANGE #{db_list} 0 -1\n"+
                "#{"Hint".green}: View the items in pending queue using: LRANGE #{queue_pending} 0 -1\n"+
                "#{"Hint".green}: View the last item in the pending queue using: LINDEX #{queue_pending} 0"
        end
        return true
      end


      # This method returns a numeric id as expected by data.pr.gov
      # unfotunately, data.pr.gov cannot handle our previous hashed and salted
      # version of our transactions ids which we customized for them, thus
      # we removed that code and resorted to creating a global counter of numeric
      # ids. These ids are visible by the endpoint that shows stats, used by
      # our data extractor (cap_script.py), which retrives our API data
      # and stores it as a csv, which is later uploaded to data.pr.gov.
      #
      # This instance method checks if this object has a numeric_id.
      # The numeric_id is retrieved from a global counter and is set the
      # first time a transaction is saved. Since we have 32k legacy transactions
      # that do not have an id, we created this method as the proper way to access
      # and update those transactions when they show up no the stats list,
      # and return a numeric id.
      def get_numeric_id
          # if no numeric_id found, grab one from the store
          if(@numeric_id == nil)
             @numeric_id = Store.db.incr("#{Transaction.db_global_prefix}:numeric_id_count")
             # update the transaction in the store
             save
          end
          # return the transaction numeric id
          return @numeric_id
      end

      # This is the
      # Additional info:
      # This method is private & not meant to be called directly only through save.
      # This method saves using a redis pipeline, which means that all commands
      # in the pipeline block are actually called in a single request
      # on the database. It is very important that within the
      # pipeline block, any interaction with the database, be it an instance
      # method or class method, uses the db_connection already opened for the
      # pipeline. Store.db must not be called directly or indirectly from within
      # that pipeline, or else a new connection from the Connection Pool would
      # be used, which would lead to instability in the system. By recycling the
      # same db connection, we make the system perform with excellent performance.
      #
      def pipelined_save(json, first_save=false)
          if Config.display_hints
            debug "Store Pipeline: Attempting to save transaction in Store under key \"#{db_id}\""
            debug "Store Pipeline: Attempting to save into recent transactions list \"#{db_list}\""
            debug "Store Pipeline: Attempting to save into \"#{queue_pending}\" queue"
          end

          # This is where we do an atomic save on the database. We grab a
          # connection from the pool, and use it. If a connection is unavailable
          # the code (Fiber) will be on hold, and will magically resume properly
          # thanks to our use of EM-Synchrony.
          Store.db.pipelined do |db_connection|
            # don't worry about an error here, if the db isn't available
            # it'll raise an exception that will be caught by the system

            # Update the transaction object in the database by storing the JSON
            # in the key under this ID in the database store.
            db_connection.set(db_id, json)

            # If TTL is not nil, update the Time to Live everytime a transaction
            # is saved/updated
            if(EXPIRATION > 0)
              db_connection.expire(db_id, EXPIRATION)
            end

            # if this is the first time this transaction is saved:
            if first_save
              # Add it to a list of the last couple of items
              db_connection.lpush(db_list, db_cache_info)
              # trim the items to the maximum allowed, determined by this constant:
              db_connection.ltrim(db_list, 0, LAST_TRANSACTIONS_TO_KEEP_IN_CACHE)

              # Add it to our GMQ pending queue, to be grabbed by our workers
              # Enqueue a email notification job
              db_connection.rpush(queue_pending, job_notification_data)
              # Enqueue a rapsheet validation job
              # db_connection.rpush(queue_pending, job_rapsheet_validation_data)

              # We can't use any method that uses Store.db here
              # because that would cause us to checkout a db connection from the
              # pool for each of those commands; the pipelined commands need to
              # run on the same connection as the commands in the pipeline,
              # so we will not use the Store.add_pending method. For any
              # of our own method that requires access to the db, we will
              # recycle the current db_connection. In this case, the add_pending
              # LibraryHelper method supports receiving an existing db connection
              # which makes it safe for the underlying classes to perform
              # database requests, appending them to this pipeline block.
              add_pending(db_connection)
            end # end of first_save for new transactions
          end
          debug "Saved!".bold.green
      end


      # Requeue a transaction. If this is ever used in a pipelined request
      # the db_connection must be provided. If used as a simple method,
      # it'll pick a connection from the pool to the db
      def requeue_rapsheet_job(db_connection = nil)
        # if we're not being used inside a pipelined request, grab an
        # existing connection from the db pool
        if(db_connection.nil?)
          # call the rapsheet validation job with 'mute' paramter as true
          # to supress notifications when re-queing
          Store.db.rpush(queue_pending, job_rapsheet_validation_data(true))
        else
          # when a connection is provided, such as for a pipelined request
          # use it:
          # call the rapsheet validation job with 'mute' paramter as true to
          # supress notifications when re-queing
          db_connection.rpush(queue_pending, job_rapsheet_validation_data(true))
        end

        # update the status
        @status = "requeued"
        @location = "PR.gov GMQ"
        @state = :validating_rapsheet_with_sijc
        # save the transaction state
        save
        return true
      end

      # Instance method to retrieve this certificate if it been generated in RCI
      # in the past. If we provide a callback as true, the system will request a
      # callback be initiated to the GMQ to deliver the certificate.
      # If you just want the base64, you simply set the callback as false.
      # If you need the final process to be executed, including mailing the user
      # the certificate, then you must invoke the callback as true.
      def queue_retrieve_certificate_job(db_connection = nil, callback=false)
        # if we're not being used inside a pipelined request, grab an
        # existing connection from the db pool
        if(db_connection.nil?)
          # call the rapsheet validation job with 'mute' paramter as true
          # to supress notifications when re-queing
          Store.db.rpush(queue_pending, job_certificate_retrieve_data(callback))
        else
          # when a connection is provided, such as for a pipelined request
          # use it:
          # call the rapsheet validation job with 'mute' paramter as true to
          # supress notifications when re-queing
          db_connection.rpush(queue_pending, job_certificate_retrieve_data(callback))
        end

        # update the status
        @status = "requeued"
        @location = "PR.gov GMQ"
        @state = :retrieving_certificate_from_rci
        # save the transaction state
        save
        return true
      end

      # Called when the transaction's certificate has been generated.
      # in the case of this API it means SIJC's RCI has generated the
      # the certificate
      def certificate_ready(params)
          # validate these parameters. If this passes, we can safely import
          params = validate_certificate_ready_parameters(params)
          # since we may turn off displaying results for production server
          # in order to skip displaying base64 certificates in logs and
          # console, here we display a notification to make sure we
          # show what transaction we're processing
          puts "Processing certificate for transaction #{params['id']}"
          self.certificate_base64          = params["certificate_base64"]
          # Generate the Certificate job:
          Store.db.rpush(queue_pending, job_generate_negative_certificate_data)
      end


      # Called when the transaction has completed a manual review
      # in the case of this API, it means an analyst at the PRPD
      # completed a manaul review of a request.
      def review_complete(params)
          # validate these parameters. If this passes, we can safely import.
          params = validate_review_completed_parameters(params)
          self.analyst_id                 = params["analyst_id"]
          self.analyst_fullname           = params["analyst_fullname"]
          self.analyst_approval_datetime  = params["analyst_approval_datetime"]
          self.analyst_transaction_id     = params["analyst_transaction_id"]
          self.analyst_internal_status_id = params["analyst_internal_status_id"]
          self.decision_code              = params["decision_code"]
          self
      end

      # declare our private methods here
      private :pipelined_save

    end
  end
end
