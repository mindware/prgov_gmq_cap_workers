# Require the base functionality (config, helpers, errors, etc)
require 'app/core/workers/base_worker'
# Transaction capabilities
require 'app/models/transaction'
# Restful capabilities
require 'app/helpers/rest'

module GMQ
  module Workers
    class RapsheetRetrieveWorker < GMQ::Workers::BaseWorker

      def self.perform(*args)
        super # call base worker perform
        payload = args[0]


        # get the ID from the params. If it is missing, we error out.
        # This error is not be a candidate for a retry thanks to BaseWorker.
        if !payload.has_key? "id"
          logger.error "#{self} is missing a transaction id, and cannot continue. "+
               "This should never happen. Check the GMQ API, responsible for "+
               "providing a proper id for this job."
          puts "#{self} is missing a transaction id, and cannot continue. "+
               "This should never happen. Check the GMQ API, responsible for "+
               "providing a proper id for this job. This job will not retry."
          raise MissingTransactionId
        end


        # Let's fetch the transaction from the Data Store.
        # The following line returns GMQ::Workers::TransactionNotFound
        # if the given Transaction id is not found in the system.
        # BaseWorker will not retry a job for a transaction that is not found.
        begin
          transaction = Transaction.find(payload["id"])
        # Detect any Transaction not found errors and log them properly
        rescue GMQ::Workers::TransactionNotFound => e
          logger.error "#{self} could not find transaction id "+
                       "#{payload["id"]}. This job will not be retried."
          puts "#{self} could not find transaction id #{payload["id"]}. This "+
               " job will not be retried."
          # re-raise so that it's caught by resque and the job isn't retried.
          raise e
        # When worker termination is requested via the SIGTERM signal,
        # Resque throws a Resque::TermException exception. Handling
        # this exception allows the worker to cease work on the currently
        # running job and gracefully save state by re-enqueueing the job so
        # it can be handled by another worker.
        # Every begin/rescue needs this rescue added
        rescue Resque::TermException
          Resque.enqueue(self, args)
        # log any other exceptions, but let resque retry according to our
        # BaseWorker specifications.
        rescue Exception => e
          logger.error "#{self} encountered a #{e.class.to_s} error while "+
               "fetching transaction #{payload["id"]}."
          puts "#{self} encountered a #{e.class.to_s} error while "+
               "fetching transaction #{payload["id"]}."
          # re-raise so that it's caught by resque
          raise e
        end

        # Lets move forward:
        # update the transaction status and save it
        transaction.status = "processing"
        transaction.state = :retrieving_certificate_from_rci
        transaction.save

        # Grab the environment credentials for RCI
        user = ENV["SIJC_RCI_USER"]
        pass = ENV["SIJC_RCI_PASSWORD"]
        # generate url & query
        url = "#{ENV["SIJC_PROTOCOL"]}://#{ENV["SIJC_IP"]}#{ENV["SIJC_PORT"]}/v1/api/rap/retrieve"

        query = ""
        query << "?tx_id=#{transaction.id}"
	# here we append the callback_url only if it has been provided and is true 
        callback_url = "#{ENV["CAP_API_PUBLIC_PROTOCOL"]}://#{ENV["CAP_API_PUBLIC_IP"]}#{ENV["CAP_API_PUBLIC_PORT"]}/v1/cap/transaction/certificate_ready"
        query << "&callback_url=#{callback_url}" if payload["callback_url"].to_s == "true"

        payload = ""
        # method = "put"
        # type = "json"
        method = "get"
        type   = "text/html; charset=utf-8"

        begin
          a = Rest.new(url, user, pass, type, payload, method, query)
          logger.info "#{self} is processing #{transaction.id}, "+
                      "requesting: URL: #{a.site}, METHOD: #{a.method}, "+
                      "TYPE: #{a.type}"
          response = a.request
          logger.info "HTTP Code: #{response.code}\n"+
                      "Headers: #{response.headers}\n"
          puts        "HTTP Code: #{response.code}\n"+
                      "Headers: #{response.headers}\n"
          case response.code
            when 200

              # Try to update the transaction info and stats,
              # ignore it if it fails. We have to ignore because
              # a retry at this step would result in multiple
              # calls and callbacks to RCI's API because of this
              # step, so we try and otherwise ignore any failures.
              # we don't want users or rci getting spammed.
              begin
		if(payload["callback_url"].to_s == "true")
			# If we performed a callback for retrieval
			# make sure we perform the proper statistics
			# modification so that our stats dont become
			# incorrect. 
			transaction.remove_completed
			transaction.add_pending
		end
                transaction.identity_validated = true
                transaction.location = "SIJC RCI"
                transaction.status = "done"
                transaction.state = :done_retrieving_certificate_from_rci
                transaction.save
              rescue Resque::TermException
                Resque.enqueue(self, args)
                # done - return reponse and wait for our sijc callback
              rescue Exception => e
                # continue
                puts "Error: #{e} ocurred"
              end

              # return the response
              response
            when 400
              json = JSON.parse(response)
              logger.error "RCI ERROR PAYLOAD: #{json["status"]} - "+
                                              "#{json["code"]} - "+
                                              "#{json["message"]} - "+
					      "for #{transaction.id}" 
	      response
            # 500 errors are internal server errors. They will be
            # retried. Here we allow RestClient to raise an Exception
            # which will be caught by the system and retried.
            when 500
              # do proper notification of the problem:
              logger.error "#{self} received 500 error when processing "+
              "#{transaction.id} and connecting to URL: #{a.site}, METHOD: "+
              "#{a.method}, TYPE: #{a.type}."
              puts "#{self} received 500 error when processing "+
              "#{transaction.id} and connecting to URL: #{a.site}, METHOD: "+
              "#{a.method}, TYPE: #{a.type}."
              response.return!(request, result, &block)
            # Any other http error codes are processed. Such as 301, 302
            # redirections, etc are properly processed and we allow Restclient
            # to decide what to do in those cases, such as follow, or throw
            # Exceptions
            else
              response.return!(request, result, &block)
          end
        rescue RestClient::Exception => e
          logger.error "Error #{e} while processing #{transaction.id}. "+
          "WORKER REQUEST: URL: #{a.site}, METHOD: #{a.method}, TYPE: #{a.type} "+
          "Error detail: MESSAGE: #{e.message} - DETAIL: #{e.inspect.to_s}."
          puts "Error #{e} while processing #{transaction.id}. "+
          "WORKER REQUEST: URL: #{a.site}, METHOD: #{a.method}, TYPE: #{a.type} "+
          "Error detail: #{e.inspect.to_s} MESSAGE: #{e.message}."
          # add error statistics to this transaction
          begin
            transaction.rci_error_count = (transaction.rci_error_count.to_i) + 1
            transaction.rci_error_date  = Time.now
            transaction.last_error_type = "#{e}"
            transaction.last_error_date = Time.now
            transaction.status = "retrying"
            transaction.state = :error_retrieving_certificate_from_sijc
            transaction.save
          rescue Resque::TermException
            Resque.enqueue(self, args)
          rescue Exception => e
            # continue
            puts "Error: #{e} ocurred"
          end
          raise GMQ::RCI::ApiError, "#{e.inspect.to_s} - WORKER REQUEST: "+
          "URL: #{a.site}, METHOD: #{a.method}, TYPE: #{a.type}"
        # Timed out - Happens when a network error doesn't permit
        # us to communicate with the remote API.
        rescue Errno::ETIMEDOUT => e
          logger.error "Could Not Connect - #{e} while processing #{transaction.id}. "+
          "WORKER REQUEST: URL: #{a.site}, METHOD: #{a.method}, TYPE: #{a.type} "+
          "Error detail: MESSAGE: #{e.message} - DETAIL: #{e.inspect.to_s}."
          puts "Error #{e} while processing #{transaction.id}. "+
          "WORKER REQUEST: URL: #{a.site}, METHOD: #{a.method}, TYPE: #{a.type} "+
          "Error detail: #{e.inspect.to_s} MESSAGE: #{e.message}."

          # add error statistics to this transaction but ignore
          # any errors when doing so
          begin
            transaction.rci_error_count = (transaction.rci_error_count.to_i) + 1
            transaction.rci_error_date  = Time.now
            transaction.last_error_type = "#{e}"
            transaction.last_error_date = Time.now
            transaction.status = "retrying"
            transaction.state = :failed_retrieving_certificate_from_sijc
            transaction.save
          # When worker termination is requested via the SIGTERM signal
          rescue Resque::TermException
            Resque.enqueue(self, args)
          rescue Exception => e
            # ignore errors and continue
            puts "Error: #{e} ocurred"
          end

          raise GMQ::RCI::ConnectionTimedout, "#{self} #{e.inspect.to_s} - WORKER REQUEST: "+
          "URL: #{a.site}, METHOD: #{a.method}, TYPE: #{a.type}"
        # Catch SIGTERM and Renenque
        rescue Resque::TermException
          Resque.enqueue(self, args)
        # Everything else
        rescue Exception => e
          # we will catch and rethrow the error.
          logger.error "#{e} while processing #{transaction.id}. "+
          "WORKER REQUEST: URL: #{a.site}, METHOD: #{a.method}, TYPE: #{a.type} "+
          "Error detail: MESSAGE: #{e.message} - DETAIL: #{e.inspect.to_s}."
          puts "Error #{e} while processing #{transaction.id}. "+
          "WORKER REQUEST: URL: #{a.site}, METHOD: #{a.method}, TYPE: #{a.type} "+
          "Error detail: MESSAGE: #{e.message} Detail: #{e.inspect.to_s}."
          # add error statistics to this transaction
          # errors here might include things that won't let us perform
          # this step, so we wrap this in a begin/rescue and ignore errors
          # from this attempt. If it works great, if not. Read the logs.
          begin
            transaction.rci_error_count = (transaction.rci_error_count.to_i) + 1
            transaction.rci_error_date  = Time.now
            transaction.last_error_type = "#{e}"
            transaction.last_error_date = Time.now
            transaction.status = "waiting"
            transaction.state = :failed_retrieving_certificate_from_sijc
            transaction.save
          rescue Resque::TermException
            Resque.enqueue(self, args)
          rescue Exception => e
            puts "Error: #{e} ocurred"
          end
          # now raise the error
          raise e
        end # end of begin/rescue

        # When worker termination is requested via the SIGTERM signal,
        # Resque throws a Resque::TermException exception. Handling
        # this exception allows the worker to cease work on the currently
        # running job and gracefully save state by re-enqueueing the job so
        # it can be handled by another worker.
        # Every begin/rescue needs this rescue added
        rescue Resque::TermException
          Resque.enqueue(self, args)
      end # end of perform
    end # end of class
  end # end of worker module
end # end of GMQ module
