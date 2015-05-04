# import date and time functionality
require 'date'
# JSON parser
require 'json'
# Require the base functionality (config, helpers, errors, etc)
require 'app/core/workers/base_worker'
# Transaction capabilities
require 'app/models/transaction'
# Validator Request handling capabilities
require 'app/models/validator'
# Restful capabilities
require 'app/helpers/rest'

# This worker talks to Justice Department's RCI
# and tries to validate if a certificate exists and attempst to
# retrive the information.
module GMQ
  module Workers
    class CAPValidationWorker  < GMQ::Workers::BaseWorker

      # Set a short backoff strategy of this.
      @backoff_strategy = [5, 10, 15, 20, 35]

      def self.perform(*args)
        super # call base worker perform
        payload = args[0]

        # get the ID from the params. If it is missing, we error out.
        # This error is not be a candidate for a retry thanks to BaseWorker.
        if !payload.has_key? "id"
          logger.error "#{self} is missing a request id, and cannot continue. "+
               "This should never happen. Check the GMQ API, responsible for "+
               "providing a proper id for this job."
          puts "#{self} is missing a request id, and cannot continue. "+
               "This should never happen. Check the GMQ API, responsible for "+
               "providing a proper id for this job. This job will not retry."
          raise MissingTransactionId, "Missing the id of the request."
        end

        # Let's fetch the transaction from the Data Store.
        # The following line returns GMQ::Workers::TransactionNotFound
        # if the given Transaction id is not found in the system.
        # BaseWorker will not retry a job for a transaction that is not found.
        begin
          logger.error "Trying to find #{payload["id"]} validation request."
          transaction = Validator.find(payload["id"])
        # Detect any Transaction not found errors and log them properly
        rescue GMQ::Workers::TransactionNotFound => e
          logger.error "#{self} could not find validation request id "+
                       "#{payload["id"]}, it may have already expired. "+
                       " This job will not be retried."
          puts "#{self} could not find validation request id #{payload["id"]}. "+
          "It may have already expired. This job will not be retried."
          # re-raise so that it's caught by resque and the job isn't retried.
          raise e
        # log any other exceptions, but let resque retry according to our
        # BaseWorker specifications.
        rescue Exception => e
          logger.error "#{self} encountered a #{e.class.to_s} error while "+
               "fetching validation request id #{payload["id"]}."
          puts "#{self} encountered a #{e.class.to_s} error while "+
               "fetching validation request id #{payload["id"]}."
          # re-raise so that it's caught by resque
          raise e
        end

        # update the transaction status and save it
        transaction.status = "processing"
        transaction.state = :validating_certificate_with_rci
        transaction.location = "PR.gov GMQ"
        transaction.save

        # Grab the environment credentials for RCI
        user = ENV["SIJC_RCI_USER"]
        pass = ENV["SIJC_RCI_PASSWORD"]
        # generate url & query
        url = "#{ENV["SIJC_PROTOCOL"]}://#{ENV["SIJC_IP"]}#{ENV["SIJC_PORT"]}/v1/api/rap/validate"

        query = ""
        query << "?tx_id=#{transaction.tx_id}"

        payload = ""
        method = "get"
        type   = "text/html; charset=utf-8"

        begin
          a = Rest.new(url, user, pass, type, payload, method, query)
          logger.info "#{self} is processing #{transaction.id}, "+
                      "requesting: URL: #{a.site}, METHOD: #{a.method}, "+
                      "TYPE: #{a.type}"
          response = a.request
          logger.info "HTTP Code: #{response.code}\n"+
                      "Headers: #{response.headers}\n"+
                      "Result: #{response.to_str}\n"
          puts        "HTTP Code: #{response.code}\n"+
                      "Headers: #{response.headers}\n"+
                      "Result: #{response.to_str}\n"
          case response.code
            when 200
              # Try to update the transaction info and stats,
              # ignore it if it fails. We have to ignore because
              # a retry at this step would result in multiple
              # calls and callbacks to RCI's API because of this
              # step, so we wrap it in a begin/rescue
              # and otherwise ignore any failures.
              # we don't want users or rci getting spammed.

              # setup a flag so that we know if an error ocurred
              # when parsing the result.
              parse_error = false
              # attempt to parse the result, checking for json
              begin
                # try to save the result parsed
                transaction.result = JSON.parse(response.to_str)
                # check if this result has a transaction id
                if(transaction.result.has_key? "name" and
                  transaction.result.has_key? "generated_date" and
                  transaction.result.has_key? "birth_date")
                    logger.info "#{self} found a proper JSON in RCI result."
                    # transform the dates. Time takes its argument as seconds
                    # since epoch, not miliseconds, which is what RCI uses.
                    # so we divide by 1000 the value.
                    transaction.result["birth_date"] = Time.at(transaction.result["birth_date"].to_i / 1000 ).to_date
                    transaction.result["generated_date"] = Time.at(transaction.result["generated_date"].to_i / 1000).to_datetime
                else
                  raise GMQ::RCI::ApiError, "did not receive expected values from RCI API"
                end
              rescue Exception => e
                parse_error = true
                logger.error "#{self} encountered an error '#{e}'. "+
                             "'#{e.message}' after validating #{transaction.id}."
              end

              begin
                # if a parsing error ocurred.
                if(parse_error)
                    transaction.error_count = (transaction.error_count.to_i) + 1
                    transaction.last_error_type = "RCI returned an invalid JSON. Could not parse."
                    transaction.last_error_date = Time.now
                    transaction.location = "PR.Gov GMQ"
                    transaction.status = "failed"
                    transaction.state = :failed_validating_certificate_with_rci
                    # save the output of rci, this will expire in the store
                    # in a couple of minutes.
                    transaction.result = response.to_str
                    transaction.save
                    # done - return reponse and wait for our sijc callback
                else
                    transaction.location = "PR.Gov GMQ"
                    transaction.status = "completed"
                    transaction.state = :done_validating_certificate_with_rci
                    # since the parsing of result worked, we now simply save it.
                    transaction.save
                    # done - return reponse and wait for our sijc callback
                end
              # Catch any potential database errors in this attempt
              rescue Exception => e
                logger.error "#{self} encountered error "+
                             "#{e}, after validating #{transaction.id}"
              end
              # return the response
              response
            when 400
              # Try to update the transaction status,
              # ignore it if it fails.
              begin
                # This is an error from the API. Proceed to handle it properly:
                json = JSON.parse(response)
                logger.error "RCI ERROR PAYLOAD: #{json["status"]} - "+
                                                "#{json["code"]} - "+
                                                "#{json["message"]}"

                # update the object values
                transaction.location = "PR.gov GMQ"
                transaction.result = response.to_str
                transaction.status = "failed"
                transaction.state = :failed_validating_certificate_with_rci
                transaction.error_count = (transaction.error_count.to_i) + 1
                transaction.last_error_date = Time.now
                # Detail the actual error from the API
                if(json["code"].to_s == "2002")
                  # Transaction not found
                  transaction.last_error_type = "Transaction not found in RCI."
                elsif(json["code"].to_s == "1001")
                  transaction.last_error_type = "We did not provide a transaction id."
                elsif(json["code"].to_s == "2001")
                  transaction.last_error_type = "Transaction has an invalid length."
                end

                # update the object in the store
                transaction.save

                # update global statistics.
                # transaction.remove_pending
                # transaction.add_completed
              rescue Exception => e
                puts "Error: #{e} ocurred"
                logger.error "#{self} encountered an #{e} error before updating validation request in the datastore."
              end

              # Here we should go error by error to identify exactly
              # what SIJC mentioned and deal with it accordingly
              # and notify the user after x amount of failures.
              # We could catch each error eventually, for now
              # a generic catch for 400s.

              # Eror Responses
              # Description
              # Http Status Code
              # Application Code
              # 400
              # 1001
              # Parameter: tx_id is required.
              #
              # The transaction has an invalid length.
              # 400
              # 2001
              #
              #
              # The provided transaction id was not found in the
              # datastore.
              # 400
              # 2002
              #
              # The service is having trouble communicating with MongoDB or something was wrong saving the
              # An unexpected error ocurred while processing the request.
              # 500
              # 9999
              # Unexpected Error.


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

              # add error statistics to this transaction
              # later we could check wether the error is
              # a specific code or not.
              begin
                # increase the counter. if nil, it defaults to 0.
                transaction.error_count = (transaction.error_count.to_i) + 1
                transaction.last_error_type = "#{e}"
                transaction.last_error_date = Time.now
                transaction.status = "retrying"
                transaction.location = "PR.gov GMQ"
                transaction.state = :failed_validating_certificate_with_rci
                transaction.save
              rescue Exception => e
                puts "Error: #{e} ocurred"
              end

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
            transaction.error_count = (transaction.error_count.to_i) + 1
            transaction.last_error_type = "#{e}"
            transaction.last_error_date = Time.now
            transaction.status = "retrying"
            transaction.state = :failed_validating_certificate_with_rci
            transaction.save
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
            transaction.error_count = (transaction.error_count.to_i) + 1
            transaction.last_error_type = "#{e}"
            transaction.last_error_date = Time.now
            transaction.status = "retrying"
            transaction.state = :failed_validating_certificate_with_rci
            transaction.save
          rescue Exception => e
            # ignore errors and continue
            puts "Error: #{e} ocurred"
          end

          raise GMQ::RCI::ConnectionTimedout, "#{self} #{e.inspect.to_s} - WORKER REQUEST: "+
          "URL: #{a.site}, METHOD: #{a.method}, TYPE: #{a.type}"
        # All other errors.
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
            transaction.error_count = (transaction.error_count.to_i) + 1
            transaction.last_error_type = "#{e}"
            transaction.last_error_date = Time.now
            transaction.status = "retrying"
            transaction.state = :failed_validating_certificate_with_rci
            transaction.save
          rescue Exception => e
            puts "Error: #{e} ocurred"
          end
          # now raise the error
          raise e
        end # end of begin/rescue
      end # end of perform
    end # end of class
  end # end of worker module
end # end of GMQ module
