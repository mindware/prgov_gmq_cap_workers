require 'app/core/workers/base_worker'
require 'app/helpers/mailer'
require 'app/helpers/config'

require 'app/models/transaction'

module GMQ
  module Workers
    class EmailWorker < GMQ::Workers::BaseWorker

      def self.perform(*args)
        payload = args[0]
        if payload.has_key? "message"
          puts "\n\nPAYLOAD: #{payload["message"]}\n\n"
          t = Transaction.find(payload["id"])
          puts "Found Transaction email: #{t.email}".red
          Mailer.mail(t.email,
                      Config.all["system"]["smtp"]["from"],
                      "PR.Gov Test",
                      "This is the text",
                      "#{payload["message"]}<br>Your transaction is "+
                      "#{payload["id"]}</b>")
        else
          puts "\n\nNO PAYLOAD #{payload}\n\n"
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
