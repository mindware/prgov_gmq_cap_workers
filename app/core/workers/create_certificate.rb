require 'app/core/workers/base_worker'
require 'app/models/certificate'

module GMQ
  module Workers
    class CreateCertificate < BaseWorker

      def self.perform(*args)
        # our magic/heavy lifting goes here.
      end
    end
  end
end
