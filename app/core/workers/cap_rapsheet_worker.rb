# Require the base functionality (config, helpers, errors, etc)
require 'app/core/workers/base_worker'
# Transaction capabilities
require 'app/models/transaction'
# Restful capabilities
require 'app/helpers/rest'

module GMQ
  module Workers
    class RapsheetWorker < GMQ::Workers::BaseWorker

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

        # update the transaction status and save it
        transaction.status = "processing"
        transaction.state = :validating_rapsheet_with_sijc
        transaction.save

        # Grab the environment credentials for RCI
        user = ENV["SIJC_RCI_USER"]
        pass = ENV["SIJC_RCI_PASSWORD"]
        # generate url & query
        url = "#{ENV["SIJC_PROTOCOL"]}://#{ENV["SIJC_IP"]}#{ENV["SIJC_PORT"]}/v1/api/rap/request"

        query = ""
        query << "?tx_id=#{transaction.id}"
        query << "&first_name=#{transaction.first_name}"
        query << "&middle_name=#{transaction.middle_name}" if !transaction.middle_name.nil?
        query << "&last_name=#{transaction.last_name}"
        query << "&mother_last_name=#{transaction.mother_last_name}" if !transaction.mother_last_name.nil?
        query << "&ssn=#{transaction.ssn}" if transaction.ssn.to_s.length > 0
        query << "&passport=#{transaction.passport}" if transaction.passport.to_s.length > 0
        query << "&license=#{transaction.license_number}"
        # Due to what we could only describe as an unfortunate accident or
        # evil incarnate joke on SIJC's part, RCI API requires the date
        # in miliseconds since epoch, so we parse
        # the CAP API date which is in the format of dd/mm/yyyy and
        # convert to miliseconds since epoch. However
        # we can't simply use DateTime.parse, because it assumes UTC.
        # Since our PR timezone is in -0400
        # lets add four hours to the UTC clock, so that we end up at 12am
        # for the specific date in our timezone when converting to time since
        # epoch. Note, if you don't add the 4 hours, you end up in the day
        # before. Thus, writing this next line was as 'fun' as it sounds.
        epoch_time = DateTime.strptime("#{transaction.birth_date} 4",
                                       "%d/%m/%Y %H").strftime("%Q")
        logger.info "#{self} is transforming birthdate: #{transaction.birth_date} to epoch time #{epoch_time}."
        query << "&birth_date=#{epoch_time}"

        callback_url = "#{ENV["CAP_API_PUBLIC_PROTOCOL"]}://#{ENV["CAP_API_PUBLIC_IP"]}#{ENV["CAP_API_PUBLIC_PORT"]}/v1/cap/transaction/certificate_ready"
        query << "&callback_url=#{callback_url}"

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
              # step, so we try and otherwise ignore any failures.
              # we don't want users or rci getting spammed.
              begin
                transaction.identity_validated = true
                transaction.location = "SIJC RCI"
                transaction.status = "processing"
                transaction.state = :waiting_for_sijc_to_generate_cert
                transaction.save
                # # update global statistics
                # TODO: we whould only update a new type of completed
                # relating to positive or negative validations. Only
                # the final email worker will mark remove pending and completed.
                # so commenting for now:
                # transaction.remove_pending
                # transaction.add_completed
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
                                              "#{json["message"]}"

              # Try to update the transaction status,
              # ignore it if it fails.
              begin
                # update the transaction
                transaction.identity_validated = false
                transaction.location = "Mail"
                # TODO: update this status later so that if
                # its a fuzzy result we mark as waiting
                transaction.status = "completed"
                transaction.state = :failed_validating_rapsheet_with_sijc
                transaction.save
                # update global statistics
                transaction.remove_pending
                transaction.add_completed
              rescue Exception => e
                puts "Error: #{e} ocurred"
                logger.error "#{self} encountered an #{e} error while updating transaction. Ignoring."
              end

              if transaction.language == "english"
                subject = "We could not validate your information"
                message = "The information provided to us did not match "+
                          "that which is stored in our government systems. "+
                          "When requesting a Goodstanding Certificate "+
                          "it's important to make sure that the information "+
                          "you provide matches exactly the information "+
                          "as it appears in the ID of the "+
                          "identification method you've selected.\n\n"+
                          "RCI Error: #{json["message"]}"
                html = "The information provided to us did not match "+
                          "that which is stored in our government systems. "+
                          "When requesting a Goodstanding Certificate "+
                          "it's important to make sure that the information "+
                          "you provide matches exactly the information "+
                          "as it appears in the identification of the "+
                          "identification method you've selected.\n\n"+
                          "<i>RCI Error: #{json["message"]}</i>"
              else
                # spanish
                subject = "Error en la validación de su solicitud"
                message = "Le informamos que la información "+
                          "tal como nos fue suministrada no pudo ser "+
                          "corroborada en los sistemas gubernamentales.\n\n"+
                          "Al solicitar el Certificado de Antecedentes "+
                          "Penales debe asegurarse solicitar con la "+
                          "informacióntal tal cual "+
                          "aparece en la identificación del metodo de "+
                          "identificación seleccionado.\n\n"+
                          "RCI Error: #{json["message"]}"
                html =    "Le informamos que la información "+
                          "tal como nos fue suministrada no pudo ser "+
                          "corroborada en los sistemas gubernamentales.\n\n"+
                          "Al solicitar el Certificado de Antecedentes "+
                          "Penales debe asegurarse solicitar con la "+
                          "informacióntal tal cual "+
                          "aparece en la identificación del metodo de "+
                          "identificación seleccionado.\n\n"+
                          "<i>RCI Error: #{json["message"]}</i>".gsub("\n", "<br/>")
              end
              logger.info "#{self} is enqueing an EmailWorker for #{transaction.id}"
              Resque.enqueue(GMQ::Workers::EmailWorker, {
                  "id"   => transaction.id,
                  "subject" => subject,
                  "text" => message,
                  "html" => html,
              })

              # ENQUE WORKER to notify USER of faliled communication
              # with SIJC's RCI.

              # Here we should go error by error to identify exactly
              # what SIJC mentioned and deal with it accordingly
              # and notify the user after x amount of failures.
              # We could catch each error eventually, for now
              # a generic catch for 400s.

              # Eror Responses
              # Description
              # Http Status Code
              # Application Code
              # Message
              # The social security number is a required parameter for the request.
              # 400
              # 1001
              # Parameter: ssn is required.
              #
              # The license number is a required parameter for the request.
              # 400
              # 1002
              #
              # Parameter: license_number is required.
              # The first name is a required parameter for the request.
              # 400
              # 1003
              #
              # Parameter: first_name is required.
              # The last name is a required parameter for the request.
              # 400
              # 1004
              #
              # Parameter: last_name is required.
              # The birth date is a required parameter for the request.
              # 400
              # 1005
              #
              # Parameter: birth_date is required.
              # The value provided on the birth date does not correspond to a valid date.
              # 400
              # 1006
              #
              # The birth date provided does not represent a valid birth date.
              # The social security number provided does not match with the social security number on the record identified on the external service.
              # 400
              # 2001
              #
              # Invalid ssn provided.
              # The license number provided does not match name on the record identified on the external service.
              # 400
              # 2002
              #
              # Invalid license number provided.
              # The name provided does not match name on the record identified on the external service.
              # 400
              # 2003
              #
              # Invalid name provided.
              # The birth date provided does not match birth date on the record identified on the external service.
              # 400
              # 2004
              #
              # Invalid birth date provided.
              # The external service did not return any results matching the search criteria.
              # 400
              # 3001
              #
              # Could not identify individual on external service.
              # The external service returned multiple results matching the search criteria.
              # 400
              # 3002
              #
              # Multiple results found on external service. DTOP.
              # The service couldn’t identify precisely the information submitted.
              # How this differs from a fuzzy search isn't clear.
              # 400
              # 3003
              #
              # DTOP service is down or having a problem.
              # 500
              # 4000
              #
              # Fuzzy Search. Couldn't identify properly the profile on the criminal record registry.
              # The document store is having problems persisting requests or it’s simply down.
              # 500
              # 8000
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
                transaction.rci_error_count = (transaction.rci_error_count.to_i) + 1
                transaction.rci_error_date  = Time.now
                transaction.last_error_type = "#{e}"
                transaction.last_error_date = Time.now
                transaction.status = "retrying"
                transaction.state = :failed_validating_rapsheet_with_sijc
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
            transaction.rci_error_count = (transaction.rci_error_count.to_i) + 1
            transaction.rci_error_date  = Time.now
            transaction.last_error_type = "#{e}"
            transaction.last_error_date = Time.now
            transaction.status = "retrying"
            transaction.state = :failed_validating_rapsheet_with_sijc
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
            transaction.rci_error_count = (transaction.rci_error_count.to_i) + 1
            transaction.rci_error_date  = Time.now
            transaction.last_error_type = "#{e}"
            transaction.last_error_date = Time.now
            transaction.status = "retrying"
            transaction.state = :failed_validating_rapsheet_with_sijc
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
            transaction.rci_error_count = (transaction.rci_error_count.to_i) + 1
            transaction.rci_error_date  = Time.now
            transaction.last_error_type = "#{e}"
            transaction.last_error_date = Time.now
            transaction.status = "waiting"
            transaction.state = :failed_validating_rapsheet_with_sijc
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
