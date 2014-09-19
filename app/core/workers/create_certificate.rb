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
        if(transaction.certificate_base64)
           cert = Certificate.new
           cert.load_data(transaction.certificate_base64)
           file = "#{Config.all["system"]["temp_dir"]}files/pdf/#{transaction.id}.pdf"
           # try to save the pdf file. This either returns true or exception
           if(cert.dump(file))
              puts "Created a valid PDF file in #{file}."
              logger.info "Created a valid PDF file in #{file}."

              Resque.enqueue(GMQ::Workers::FinalEmailWorker, {
                  "id"   => transaction.id,
                  "file_path" => file,
                  "file_rename" => "certificado_prgov.pdf",
                  "text" => "This is a great message. Your cert is ready",
                  "html" => "This is a great message.<b>Your certificate is ready</b>"
              })
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