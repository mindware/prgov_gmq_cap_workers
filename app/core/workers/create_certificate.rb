# Require the base functionality (config, helpers, errors, etc)
require 'app/core/workers/base_worker'
# Transaction capabilities
require 'app/models/transaction'
# Add certificate capabilities
require 'app/models/certificate'

module GMQ
  module Workers
    class CreateCertificate < BaseWorker

      def self.perform(*args)
        super # call base worker perform
        payload = args[0]
        # Get the ID from the job parameters. If it is missing, we error out.
        # TODO This error should not be a candidate for a retry
        raise MissingTransactionId if !payload.has_key? "id"

        puts "Certificate creation requested for #{payload["id"]}."

        # Let's fetch the transaction from the Data Store.
        # The following line returns GMQ::Workers::TransactionNotFound
        # if the given Transaction id is not found in the system.
        # BaseWorker will not retry a job for a transaction that is not found.
        transaction = Transaction.find(payload["id"])

        # puts "transaction: #{transaction.id} #{transaction.certificate_base64.nil?}"
        if(transaction.certificate_base64.to_s.length > 0)
           cert = Certificate.new
           cert.load_data(transaction.certificate_base64)
           file = "#{Config.all["system"]["temp_dir"]}#{transaction.id}.pdf"
           # try to save the pdf file. This either returns true or exception
           if(cert.dump(file))
              puts "Created a valid PDF file in #{file}."
              logger.info "Created a valid PDF file in #{file}."

              # Try to update the transaction status,
              # ignore it if it fails.
              begin
                # update the transaction
                transaction.location = "PR.gov GMQ"
                transaction.status = "processing"
                transaction.state = :mailing_certificate
                transaction.save
              rescue Exception => e
                puts "Error: #{e} ocurred"
                logger.error "#{self} encountered an #{e} error while updating transaction. Ignoring."
              end

              if(transaction.language == "english")
                  Resque.enqueue(GMQ::Workers::FinalEmailWorker, {
                      "id"   => transaction.id,
                      "file_path" => file,
                      "file_rename" => "certificado_prgov.pdf",
                      "text" => "The result of the Certificate of Good Standing "+
                                "request is attached. This concludes our job "+
                                "relating to the request id #{transaction.id}. Thank "+
                                "you for using our services.",
                      "html" => "<b>The result of the Certificate of Good Standing "+
                                "request is attached. This concludes our job "+
                                "relating to the request id #{transaction.id}. "+
                                "Thank you for using our "+
                                "services.</b>"
                  })
              else
                  # spanish
                  Resque.enqueue(GMQ::Workers::FinalEmailWorker, {
                      "id"   => transaction.id,
                      "file_path" => file,
                      "file_rename" => "certificado_prgov.pdf",
                      "text" => "Le incluimos el resultado de la solicitud "+
                                "número #{transaction.id} relacionada a un "+
                                "Certificado de Antecedentes "+
                                "Penales. Favor de ver el documento adjunto. "+
                                "Gracias por utilizar nuestros "+
                                "servicios.",
                      "html" => "<b>Le incluimos el resultado de la solicitud "+
                                "número #{transaction.id} relacionada a un "+
                                "Certificado de Antecedentes "+
                                "Penales. Favor de ver el documento adjunto. "+
                                "Gracias por utilizar nuestros "+
                                "servicios.</b>"
                  })
              end
           else
              puts "Could not create a valid PDF file in #{file}"
              logger.error "Could not create a valid PDF file in #{file}"
           end
        else
           puts "Base64 certificate not found!"
           logger.error "Base64 Certificate not found for #{transaction.id}"
        end
      end # end of perform

    end # end of class
  end # end of workers module
end # end of GMQ module
