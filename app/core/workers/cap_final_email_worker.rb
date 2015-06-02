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

          logger.info "#{self} is processing #{transaction.email}"

          # Append the email
          payload["to"] = transaction.email
          payload["from"]  = Config.all["system"]["smtp"]["from"]
          if(transaction.language == "english")
            payload["subject"] = "PR.Gov - Good Standing Certificate Attached"
          else
            payload["subject"] = "PR.Gov - Adjunto Certificado de Antecedentes Penales"
          end

          # Use our GMQ Mailer class to mail the payload.
          if(Mailer.mail_payload(payload))
              logger.info "#{self} Successfully mailed certificate to #{transaction.email} for #{transaction.id}."
              # Clean up the files before we even think of updating the
              # transaction. We want to make sure the file system gets cleaned
              # before we risk a failure on saving in the db
              #
              # Now. If the file is a PDF, then we proceed to delete
              # what the worker was asked to delete. Yeah, let's not trust
              # ourselves.
              if(File.extname(payload["file_path"]) == ".pdf")
                 # if the pdf exists, delete it
                 if File.exists?(payload["file_path"])
                   logger.info "#{self} is deleting file #{payload["file_path"]}."
                    File.delete(payload["file_path"])
                 else
                    logger.error "#{self} could not cleanup delete "+
                                 "#{payload["file_path"]}. Odd, the file "+
                                 "was not found but it was our responsability "+
                                 "to delete it."
                 end
                 # log it
                 logger.info "#{self} - Cleanup Deleted #{payload["file_path"]}."
              else
                logger.error "#{self} was unauthorized by worker logic to attempt "+
                            "to delete #{payload["file_path"]}."
              end

              # Try to update the transaction status,
              # ignore it if it fails.
              begin
                # update the transaction
                transaction.location = "Mail"
                transaction.status = "finished"
                transaction.state = :done_mailing_certificate
                transaction.certificate_base64 = nil
                transaction.save
                # update global statistics
                transaction.remove_pending
                transaction.add_completed
              rescue Exception => e
                puts "Error: #{e} ocurred"
                logger.error "#{self} encountered an #{e} error while updating transaction. Ignoring."
              end
          else
            # we have to test to see if this is ever really reached.
            logger.info "#{self} could not mail #{transaction.email} for #{transaction.id}."
            raise Exception, "Could not mail the email for #{transaction.id}. Let's retry"
          end

        else
          # puts "\n\nNO PAYLOAD #{payload}\n\n"
          logger.error "#{self} received no payload parameters."
          raise IncorrectEmailParameters, "Invalid arguments. Text and html "+
                                          "parameters are required for email "+
                                          "worker."
        end
      end # end of perform
    end # end of class
  end # end of worker module
end # end of GMQ module
