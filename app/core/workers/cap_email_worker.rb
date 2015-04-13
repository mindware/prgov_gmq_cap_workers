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
          payload["subject"] = "PR.Gov Certificado de Buena Conducta / Goodstanding Certificate" if !payload.has_key? "subject"

          # Use our GMQ Mailer class to mail the payload.
          if(!Mailer.mail_payload(payload))
            # if it failed, raise an error so it's retried
            raise
          else
            # if mail succeeded, and we've been required to
            # request a rapsheet after the email is sent and
            # this is a transaction that is just starting (state),
            # proceed to enqueue the job.
            # Why? Because:
            # Since our systems are so fast, simply enqueing
            # a notification and a rapsheet request simultaneously
            # proved to be too fast, and the validation email arrived
            # with the certificate before the initial notification arrived
            # on many occasions. So now, we only enqueue the rapsheet
            # request after the email has been sent.
            if(payload.has_key? "request_rapsheet" and
               transaction.state.to_s == "started")
                Resque.enqueue(GMQ::Workers::RapsheetWorker, {
                    "id"   => transaction.id,
                    "queued_at" => "#{Time.now}"
                })
            end
          end
        # Else if no id provided, we allow the custom email through
        # which has already been properly validated by GMQ API.
        elsif Mailer.mail_payload(payload)
        else
          raise PRGov::IncorrectEmailParameters, "Invalid or missing arguments for email worker."
        end

      end # end of perform
    end # end of class
  end # end of worker module
end # end of GMQ module
