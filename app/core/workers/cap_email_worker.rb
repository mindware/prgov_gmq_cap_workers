require 'app/core/workers/base_worker'
require 'app/helpers/mailer'
require 'app/helpers/config'

require 'app/models/transaction'

module GMQ
  module Workers
    class EmailWorker < GMQ::Workers::BaseWorker

      def self.perform(*args)

        payload = args[0]
        if payload.has_key? "text_message" or payload.has_key["html_message"]

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
          Mailer.mail_payload(payload)
        else
          puts "\n\nNO PAYLOAD #{payload}\n\n"
          raise StandardError, "No text_message or html_message in email"
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