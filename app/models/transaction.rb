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
module PRGMQ
  module CAP
    class Transaction < PRGMQ::CAP::Base
      # We use both class and instance methods
      extend Validations
      include Validations
      include TransactionIdFactory
      extend TransactionIdFactory
      include LibraryHelper

      # If you set MONTHS_TO_EXPIRATION_OF_TRANSACTION to 0, transactions
      # will never expire. (Hint: that could fill up the database store, be
      # careful). Only do it if you know what you're doing.
      # By default, we use 1 or three months to keep the transaction in the
      # system for inspection. Once expired, it's really gone!
      # Max is 25 years (25 * 12). Don't try it.
      MONTHS_TO_EXPIRATION_OF_TRANSACTION = 3
      # The expiration is going to be 8 months, in seconds
      # Time To Live - Math:
      # 604800 seconds in a week X 4 weeks = 1 month in seconds
      # Multiply this amount for the amount of months that a transaction
      # can last before expiring.
      EXPIRATION = (604800 * 4) * MONTHS_TO_EXPIRATION_OF_TRANSACTION


      LAST_TRANSACTIONS_TO_KEEP_IN_CACHE = 50


      ######################################################
      # A transaction generally consists of the following: #
      ######################################################

      # If you add an attribute, update the initialize method and to_hash method
      attr_accessor :id,     # our transaction id
                    :email,                # user email
                    :ssn,                  # social security number
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
                    :certificate_base64,   # The base64 certificate
                    :analyst_fullname,     # The fullname of the analyst at
                                           # PRPD that authorized this request.
                    :analyst_id,           # The user id of the analyst at PRPD
                                           # that authorized this request
                                           # through their ANPE System.
                    :analyst_approval_datetime, # The exact date and time in
                                                # which the user approved this
                                                # action. This must correspond
                                                # with the tiemstamps in the
                                                # PRPD’s internal system, such
                                                # iANPE so that in the event of
                                                # an audit correlation is
                                                # possible.
                    :analyst_transaction_id,    # The internal id of the
                                                # matching request in the
                                                # ANPE DB. This id can be used
                                                # in case of an audit.
                    :analyst_internal_status_id,# The matching internal
                                                # decision code id of the ANPE
                                                # system.
                    :decision_code,             # The decision of the analyst at
                                                # PRPD of what must be done with
                                                # transaction after their
                                                # exhaustive manual review
                                                # process. The following
                                                # decisions are supplied by the
                                                # PRPD system login only:
                                                # 100 - Issue Negative Cert
                                                # 200 - May not Issue Negative
                                                #       Cert.
      # Newly created Transactions
      def self.create(params)

          # The following parameters are allowed to be retrieved
          # everything else will be discarded from the user params
          # by the validate_transaction_creation_parameters() method
          whitelist = ["email", "ssn", "license_number",
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
          tx.created_at          = Time.now.utc
          tx.status              = "received"
          tx.location            = "PR.gov GMQ"
          tx.state               = :started

          # Pending stuff that we've yet to develop:
          # tx["history"]           = { "received" => { Time.now }}
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

              # If we had servers in multiple time zones, we'd want
              # to use utc in the next two lines. This might be important
              # if we go cloud in multiple availability zones, since
              # we'll use the Time.now to order transactions.
              self.updated_at                 = Time.now.utc
          end
          return self
      end

      def initialize
          super
          @id = nil
          @email = nil
          @ssn = nil
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

      def to_json
        to_hash.to_json
      end

      # just an alias
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
            raise ItemNotFound
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

      def save
        # We have to retrieve this here, incase we ever need values here
        # from the Store. If we do it inside the multi or pipelined
        # we won't have those values availble when building the json
        # and all we'll have is a Redis::Future object. By doing
        # the following to_json call here, we would've retrieved the data
        # needed before the save.
        json = self.to_json

        # do a multi command. Doing multiple commands in an
        # atomic fashion:
        # Store.db.multi do

        # We are no longer using multi, as our Storage proxy
        # does not support multi/exec. It does support pipelining
        # however, so that's what we're using for atomic operations.
        debug "Saving transaction in Redis under key \"#{db_id}\""
        debug "View it in Redis using: GET #{db_id}"
        Store.db.pipelined do
          # don't worry about an error here, if the db isn't available
          # it'll raise an exception that will be caught by the system
          Store.db.set(db_id, json)

          # If TTL is not nil
          if(EXPIRATION > 0)
            Store.db.expire(db_id, EXPIRATION)
          end

          # We used to add them by score (time) to a sorted list
          # but we can achieve that with a simple list.
          # debug "Adding to ordered transaction list: #{db_list}"
          # debug "View it using: ZREVRANGE '#{db_list}' 0 -1"
          # Store.db.zadd(db_list, updated_at.to_i, db_id)

          # Add it to a list of the last 10 items
          Store.db.lpush(db_list, db_cache_info)
          # trim the items to the last 10
          Store.db.ltrim(db_list, 0, LAST_TRANSACTIONS_TO_KEEP_IN_CACHE)
          # after this line, db.multi runs 'exec', in an atomic fashion
          # Store.db.lpush()
        end
        true
      end


      # Called when the transaction's certificate has been generated.
      # in the case of this API it means SIJC's RCI has generated the
      # the certificate
      def certificate_ready(params)
          # validate these parameters. If this passes, we can safely import
          params = validate_certificate_ready_parameters(params)
          # self.certificate_base64          = params["certificate_base64"]
          # to reduce memory usage, we no longer store the base64 cert, we
          # merely mark it as received, and look it up in SIJC's RCI when
          # we're ready to send it via email.
          self.certificate_base64            = true
          self
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

    end
  end
end
