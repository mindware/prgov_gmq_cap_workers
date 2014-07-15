require 'securerandom'

module PRGMQ
  module CAP
    module TransactionIdFactory

      # the transaction list will always have the same name
      def generate_key
        TransactionIdFactory.generate_key
      end

      # Checks the length of our keys. We simply generate one
      # to check. Used by the Validations helper
      def transaction_key_length
         TransactionIdFactory.generate_key.length
      end

      # Checks the length of our keys. We simply generate one
      # to check. Used by the Validations helper
      def self.transaction_key_length
         self.generate_key.length
      end

      def self.generate_key
        # change this later for snow flake.
        # Always use 0 at the start.
        "0" + SecureRandom.uuid.gsub("-", "").to_s[0..16]
      end

    end
  end
end
