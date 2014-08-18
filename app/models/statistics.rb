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
      #        Increments / Decrements       #
      ########################################

      def self.add_visit(db_connection=nil)
        db_connection = Store.db if db_connection.nil?
        db_connection.incr("#{db_id}:#{visits_prefix}")
      end

      # A transaction was completed
      def self.add_completed(db_connection=nil)
        db_connection = Store.db if db_connection.nil?
        db_connection.incr("#{db_id}:#{completed_prefix}")
      end

      # increment
      def self.add_pending(db_connection=nil)
        puts "ADDING PENDING to #{db_connection.class}".red.bold
        db_connection = Store.db if db_connection.nil?
        db_connection.incr("#{db_id}:#{pending_prefix}")
      end

      # decrement a pending, this happens when
      # when we complete a task or it fails.
      def self.remove_pending(db_connection=nil)
        db_connection = Store.db if db_connection.nil?
        db_connection.decr("#{db_id}:#{pending_prefix}")
      end

      ########################################
      #                 Gets                 #
      ########################################

      # All requests that touch the database must have an optional
      # parameter to receive the connection that will be used
      # to request information from the db.
      # This is important for cases where the request is done in
      # a pipeline request, such as it is done in Transactions.
      # In pipelined or multiexec requests to the DB (in Redis)
      # A connection will already be open
      # in those cases, and if we don't have the ability to reuse
      # the connection, we would risk accidentally eating all
      # available connections, which could hang all access to the
      # Store.

      def self.visits(db_connection=nil)
        db_connection = Store.db if db_connection.nil?
        db_connection.get("#{db_id}:#{visits_prefix}")
      end

      # A transaction was completed
      def self.completed(db_connection=nil)
        db_connection = Store.db if db_connection.nil?
        db_connection.get("#{db_id}:#{completed_prefix}")
      end

      def self.pending(db_connection=nil)
        db_connection = Store.db if db_connection.nil?
        db_connection.get("#{db_id}:#{pending_prefix}")
      end

    end
  end
end
