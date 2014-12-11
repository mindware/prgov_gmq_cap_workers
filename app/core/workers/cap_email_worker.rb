require 'app/core/workers/base_worker'
require 'app/helpers/mailer'
require 'app/helpers/config'

require 'app/models/transaction'

module GMQ
  module Workers
    class EmailWorker < GMQ::Workers::BaseWorker

      def self.perform(*args)
        super # call base worker perform checks
        payload = args[0]

        if (payload.nil? or !(payload.has_key? "text" or payload.has_key? "html"))
            raise IncorrectEmailParameters, "Invalid arguments. Text and html "+
                                            "parameters are required for email "+
                                            "worker."
        end

        # If a transaction id has been provided, get the
        # data from the db.
        if payload.has_key? "id"

          # Let's fetch the transaction from the Data Store.
          # The following line returns GMQ::Workers::TransactionNotFound
          # if the given Transaction id is not found in the system.
          # BaseWorker will not retry a job for a transaction that is not found.
          transaction = Transaction.find(payload["id"])

          puts "Found Transaction email: #{transaction.email}".red

          # Append the email
          payload["to"] = transaction.email
          payload["from"]  = Config.all["system"]["smtp"]["from"]
          payload["subject"] = "PR.Gov Certificado de Buena Conducta / Goodstanding Certificate"

          # Use our GMQ Mailer class to mail the payload.
          if(!Mailer.mail_payload(payload))
            raise
          end
        # Else if no id provided, we allow the custom email through
        # which has already been properly validated by GMQ API.
        elsif Mailer.mail_payload(payload)
        else
          raise PRGov::IncorrectEmailParameters, "Invalid or missing arguments for email worker."
        end
        # data hash:
        # to
        # from
        # subject
        # text
        # html
        # id = args[""]
        # to = args["to"]
        # transaction_id = args["id"]
      end # end of perform
    end # end of class
  end # end of worker module
end # end of GMQ module
