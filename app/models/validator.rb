# This validation class is the Object that represents validation requests
# which ocurr when a user or an automation requests to validate an existing
# certificate.
#
# Since all certificates are really created in RCI, they're going to be
# the single source of truth, and each request will be validated against
# the remote system.
#
# This class basically receives a request to validate, and if all parameters
# are correct, it enqueues the job and simulatenously creates a key where
# status regarding the validation request will be updated.
#
# A request will not persist forever, however, and after a short period of
# time, whose minimum is determined by the configured expiration variables
# the transaction disappears.
require 'app/models/base'
require 'app/helpers/validations'

module GMQ
  module Workers
    class Validator < GMQ::Workers::Base

      # We use both class and instance methods
      extend Validations
      include Validations
      include LibraryHelper

      # A note on the expiration:
      # The system has been designed to expire
      # requests after time. The backup strategy
      # implemented by the system administrators will determine the longrevity
      # of the data in an alternate medium, and such will be the strategy for
      # compliance for audits that span a period of time longer than the
      # maximum retention of this system. An alternate archival strategy
      # could be implemented where transactions are stored in an alternate
      # database for inspection, but this is left as an exercise for a future
      # version of the system.

      MINUTES_TO_EXPIRATION_OF_TRANSACTION = 15
      EXPIRATION = (60 * MINUTES_TO_EXPIRATION_OF_TRANSACTION)

      LAST_TRANSACTIONS_TO_KEEP_IN_CACHE = 50

      ######################################################
      # A transaction generally consists of the following: #
      ######################################################

      # If you add an attribute, update the initialize method and to_hash method
      attr_accessor :id,                   # the id of this request in the db
                    :tx_id,                # the id of the transaction we're validating,
                    :ssn,                  # optional social security number
                    :passport,             # optional passport number
                    :IP,                   # originating IP of the requester as
                                           # claimed/forwarded by client system
                    :result,               # the result from the remote system
                    :status,               # the status pending proceessing etc
                    :state,                # the state of the machine
                    :count,                # the amounts of times this has been
                                           # requested.
                    :location,             # the system that was last assigned
                                           # the Tx to
                    :error_count,          # error count
                    :last_error_type,      # the last error
                    :last_error_date,      # and when it ocurred
                    :created_at,           # creation date
                    :updated_at,           # last update
                    :created_by,           # the user that created this
                    :certificate_base64    # the certificate encoded in base64

      # Newly created Transactions
      def self.create(params)

          # The following parameters are allowed to be retrieved
          # everything else will be discarded from the user params
          # by the validation method
          whitelist = ["tx_id", "ssn", "passport", "IP", "status",
                       "location", "created_by"]


          # Instead of trusting user input, let's extract *exactly* the
          # values from the params hash. This way, additional values
          # that may have been sneaked inside the params hash are ignored
          # safely and never reach the Store. This is done by the validate
          # method:
          # validate all the parameters in the incoming payload
          # throws valid errors if any are detected
          # it will remove non-whitelisted params from the parameters.
          params = validate_transaction_validation_parameters(params, whitelist)

          tx = self.new.setup(params)

          # Add important system defined parameters here:
          tx.id                  = generate_random_id()
          tx.created_at          = Time.now
          tx.status              = "received"
          tx.location            = "PR.gov GMQ"
          tx.result              = {}
          return tx
      end

      # Loads values from a hash into this object
      def setup(params, action=nil)
          if params.is_a? Hash
              self.id                         = params["id"]
              self.tx_id                      = params["tx_id"]
              self.ssn                        = params["ssn"]
              self.passport                   = params["passport"]
              self.IP                         = params["IP"]
              self.result                     = params["result"]
              self.status                     = params["status"]
              self.state                      = params["state"]
              self.location                   = params["location"]
              self.created_at                 = params["created_at"]
              self.created_by                 = params["created_by"]
              self.updated_at                 = params["updated_at"]
              self.certificate_base64         = params["certificate_base64"]
              self.error_count                = params["error_count"]
              self.last_error_type            = params["last_error_type"]
              self.last_error_date            = params["last_error_date"]
          end
          return self
      end

      def initialize
          super
          @id = nil
          @tx_id = nil
          @ssn = nil
          @passport = nil
          @IP = nil
          @result = nil
          @location = nil
          @status = nil
          @state = nil
          @created_at = nil
          @updated_at = nil
          @created_by = nil
          @certificate_base64 = false
          @error_count = nil
          @last_error_type = nil
          @last_error_date = nil
      end

      def to_hash
        # Grab all global global variables in this Object, and turn it into
        # a hash.
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

      # Sets the key prefix for the database.
      def self.db_prefix
        "validation"
      end

      def db_cache_info
        self.id
      end

      # Checks ttl for an request_id, after a transaction is saved
      # it stores an expiration time.
      # description:
      # gets ttl count for current item
      def ttl()
          Store.db.ttl(db_id)
      end

      def expires
          time_from_now(ttl)
      end

      # Tries to find and setup a validation object by request_id (id)
      def self.find(id)
          # if the record wasn't found
          false if id.nil?
          if(!data = Store.db.get(db_id(id)))
            puts db_id(id)
            raise TransactionNotFound
          else
            begin
              # grab the JSON from this validation id
              data = JSON.parse(data)
              # set it up into this object's variables
            rescue Exception => e
              raise InvalidNonJsonRecord
            end

            # Here we instantiate a Validation object and set it up with data
            return Validator.new.setup(data)
          end
      end
      
      # Class method that returns a list of the last transactions in the system
      # TODO: check what this returns when db is empty.
      def self.last_transactions
          Store.db.lrange(Validator.db_list, 0, -1)
      end

      # class method for transaction validation.
      # Here we request the transaction be validated against
      # the remote system that is the source of all truths regarding
      # certificates: RCI.
      def job_request_certificate_validation()
        # Here we create a hash of what the Resque system will expect in
        # the redis queue under resque:queue:prgov_cap.
        # Note: don't use single quotes for string values on JSON.
        { "class" => "GMQ::Workers::CAPValidationWorker",
                     "args" => [{
                                 "id" => "#{id}",
                                 "tx_id" => "#{self.tx_id}",
                                 "ssn" => "#{self.ssn}",
                                 "passport" => "#{self.passport}",
                                 "IP" => "#{self.IP}",
                                 "queued_at" => "#{Time.now}"
                                }]
        }.to_json
      end

      # This method returns the name of the queue we're going to use
      def queue_pending
        "resque:queue:prgov_cap"
      end

      # The public method that allows this instance to be saved to the
      # database.
      def save
        # Update the updated_at timestamp.
        self.updated_at = Time.now

        # if this was just received, this is the first save
        if self.status == "received"
            first_save = true
            self.status = "processing"
        end

        # Now lets convert the transaction object to a json. Note:
        # We have to retrieve this here, incase we ever need values here
        # from the Store. If we do it inside the multi or pipelined
        # we won't have those values availble when building the json
        # and all we'll have is a Redis::Future object. By doing
        # the following to_json call here, we retrieve the data
        # needed before the save, properly.
        json = self.to_json
        # do a pipeline command, executing all commands in an atomic fashion.
        # inform the pipelined save if this is the first time we're saving the
        # transaction, so that proper jobs may be enqueued.
        pipelined_save(json, first_save)
        # puts caller
        if Config.display_hints
          debug "#{"Hint".green}: View the validation request data in Redis using: GET #{db_id}\n"+
                "#{"Hint".green}: View the last #{LAST_TRANSACTIONS_TO_KEEP_IN_CACHE} requests using: "+
                "LRANGE #{db_list} 0 -1\n"+
                "#{"Hint".green}: View the items in pending queue using: LRANGE #{queue_pending} 0 -1\n"+
                "#{"Hint".green}: View the last item in the pending queue using: LINDEX #{queue_pending} 0"
        end
        return true
      end


      # Additional info:
      # This method saves using a redis pipeline, which means that all commands
      # in the pipeline block are actually called in a single request
      # on the database. It is very important that within the
      # pipeline block, any interaction with the database, be it an instance
      # method or class method, uses the db_connection already opened for the
      # pipeline. Store.db must not be called directly or indirectly from within
      # that pipeline, or else a new connection from the Connection Pool would
      # be used, which would lead to instability in the system. By recycling the
      # same db connection, we make the system perform as it should: excellent
      def pipelined_save(json, first_save=false)
          if Config.display_hints
            debug "Store Pipeline: Attempting to save validation request under key \"#{db_id}\""
            debug "Store Pipeline: Attempting to save into recent validation list \"#{db_list}\""
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

              # Enqueue a rapsheet validation job
              db_connection.rpush(queue_pending, job_request_certificate_validation())

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
              # add_pending(db_connection)
            end # end of first_save for new transactions
          end
          debug "Saved!".bold.green
      end

      # declare our private methods here
      private :pipelined_save

    end
  end
end
