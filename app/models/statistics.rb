module PRGMQ
  module CAP
    class Stats

      ########################################
      #                 Prefixes             #
      ########################################

      def self.db_prefix
        "stats"
      end

      # ie: get get gmq:cap:stats:visits
      def self.visits_prefix
        "visits"
      end

      def self.completed_prefix
        "completed"
      end

      def self.pending_prefix
        "pending"
      end

      def self.db_id
        "#{Store.db_prefix}:#{db_prefix}"
      end

      ########################################
      #              Increments              #
      ########################################

      def self.add_visit
        Store.db.incr("#{db_id}:#{visits_prefix}")
      end

      # A transaction was completed
      def self.add_completed
        Store.db.incr("#{db_id}:#{completed_prefix}")
      end

      # increment
      def self.add_pending
        Store.db.incr("#{db_id}:#{pending_prefix}")
      end

      # decrement
      def self.remove_pending
        Store.db.decr("#{db_id}:#{pending_prefix}")
      end

      ########################################
      #                 Gets                 #
      ########################################

      def self.visits
        Store.db.get("#{db_id}:#{visits_prefix}")
      end

      # A transaction was completed
      def self.completed
        Store.db.get("#{db_id}:#{completed_prefix}")
      end

    end
  end
end
