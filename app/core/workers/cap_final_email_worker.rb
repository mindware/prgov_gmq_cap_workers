require 'app/core/workers/base_worker'
require 'app/helpers/mailer'
require 'app/helpers/config'

require 'app/models/transaction'


# This is unused.

module GMQ
  module Workers
    class FinalEmailWorker < GMQ::Workers::BaseWorker

      def self.perform(*args)
        super # call base worker perform
        payload = args[0]
        if payload.has_key? "text" or payload.has_key? "html"
          logger.info "#{self.class} requested for #{payload["id"]}"

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

          # IMPORTANT THINGS TODO HERE!
          # TODO We should check here how the transaction ended in this final
          # email. Did things go ok? Did things go astray? Note it down update
          # the status, state and stats.
          #
          # if (something bad happened)
          #  <do something / update>
          # else
            # Everything went fine:
            # Close the transaction
            logger.info "Mail sent. Here we would update transaction state and statistics."
            # logger.info "Mail sent. Updating transaction state and statistics."
            # transaction.status = "completed"
            # transaction.state = "finished"
            # transaction.save
            # update statistics
            # TODO ideally all of this will be done against the API instead of
            # directly into the DB
            # add_completed
          # end

        else
          puts "\n\nNO PAYLOAD #{payload}\n\n"
          raise IncorrectEmailParameters, "Invalid arguments. Text and html "+
                                          "parameters are required for email "+
                                          "worker."
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
