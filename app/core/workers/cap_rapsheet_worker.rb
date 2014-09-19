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
        payload = args[0]

        # get the ID from the params. If it is missing, we error out.
        # TODO This error should not be a candidate for a retry
        raise MissingTransactionId if !payload.has_key? "id"

        # Let's fetch the transaction from the Data Store.
        # The following line returns GMQ::Workers::TransactionNotFound
        # if the given Transaction id is not found in the system.
        # BaseWorker will not retry a job for a transaction that is not found.
        transaction = Transaction.find(payload["id"])

        # Grab the environment credentials for RCI
        user = ENV["SIJC_RCI_USER"]
        pass = ENV["SIJC_RCI_PASSWORD"]
        # generate url & query
        # url = "https://66.50.173.6/v1/api/rap/request"
        # url = "http://localhost:9000/v1/cap/"
        url = "#{ENV["SIJC_PROTOCOL"]}://#{ENV["SIJC_IP"]}#{ENV["SIJC_PORT"]}/v1/api/rap/request"

        query = ""
        query << "?tx_id=#{transaction.id}"
        query << "&first_name=#{transaction.first_name}"
        query << "&middle_name=#{transaction.middle_name}" if !transaction.middle_name.nil?
        query << "&last_name=#{transaction.last_name}"
        query << "&mother_last_name=#{transaction.mother_last_name}" if !transaction.mother_last_name.nil?
        query << "&ssn=#{transaction.ssn}"
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
        query << "&birth_date=#{epoch_time}"

        # Finally generate the url, by appending the query:
        url << query

        # callback_url = 'http://servicios.pr.gov/v1/cap/missing'
        # callback_url = 'http://thoughtware.tv/api/missing_test'
        callback_url = "#{ENV["CAP_API_PUBLIC_PROTOCOL"]}://#{ENV["CAP_API_PUBLIC_IP"]}#{ENV["CAP_API_PUBLIC_PORT"]}/v1/cap/transaction/certificate_ready"
        url << "&callback_url=#{callback_url}"

        # https://***REMOVED***/v1/api/rap/request?tx_id=0123456789123456&
        # first_name=Andres&last_name=Colon&ssn=***REMOVED***&license=***REMOVED***&
        # birth_date=***REMOVED***
        # payload = {
        #       "tx_id" => transaction.id,
        #       "first_name" => transaction.first_name,
        #       "last_name" => transaction.last_name,
        #       "ssn"	=> transaction.ssn,
        #       "license"	=> transaction.license_number,
        #       "birth_date" => transaction.birth_date,
        #       "callback_url" => callback_url
        # }
        payload = ""
        # method = "put"
        # type = "json"
        method = "get"
        type   = "text/html; charset=utf-8"

        begin
        # raise AppError, "#{url}, #{user}, #{pass}, #{type}, #{payload}, #{method}"
          a = Rest.new(url, user, pass, type, payload, method)
          logger.info "#{self} is processing #{transaction.id}, "+
                      "requesting: URL: #{a.site}, METHOD: #{a.method}, "+
                      "TYPE: #{a.type}"
          response = a.request
          logger.info "HTTP Code:\n#{response.code}\n\n"
          logger.info "Headers:\n#{response.headers}\n\n"
          logger.info "Result:\n#{response.gsub(",", ",\n").to_str}\n"
          #  if response.code.to_s == 400
        rescue RestClient::Exception => e
          logger.error "Error #{e} while processing #{transaction.id}: #{e.inspect.to_s}"
          raise GMQ::RCI::ApiError, "#{e.inspect.to_s} - WORKER REQUEST: "+
          "URL: #{a.site}, METHOD: #{a.method}, TYPE: #{a.type}"
        end
      end # end of perform
    end # end of class
  end # end of worker module
end # end of GMQ module
