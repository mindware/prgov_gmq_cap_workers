# This class adds database functionality.
# Essentially it defines the key accessors that pave the way for a
# key hierarchy for the key/value storage system.
#
# The GMQ stores all keys under a global system prefix, and subsequent
# values are stored under specific keys in a hierarchy.
# ie: system_prefix:db_prefix:db_list:db_id
# which as an example, could translate to:
# ie: gmq:cap:list:01

module PRGMQ
  module CAP
    class Base

      attr_accessor :id
      ########################
      #     Class Methods    #
      ########################

      # The global system's prefix.
      # All records will be stored behind this global system prefix.
      def self.system_prefix
        Store.db_prefix
      end

      # This method will be redefined by each child class
      # This prefix is the equivalent of a storage group for this class
      # under the system. If you think as the system_prefix as the app,
      # the db_prefix is the database name, and everything under is the tables
      # (of course, this is a NoSQL DB so thinking in terms of relational
      # databases structures doesn't really do it justice)
      def self.db_prefix
        "cap"
      end

      # The prefix to be used to store lists of this class
      def self.db_list_prefix
        "list"
      end

      # Grabs the prefix from the storage,
      # adds this classes's db_prefix. This won't
      # need to be redefined by classes that
      # inherit this Base class.
      def self.db_global_prefix
        "#{self.system_prefix}:#{self.db_prefix}"
      end

      def self.queue_pending_prefix
        "pending"
      end


      # Displays the proper id for this object in the db
      def self.db_id(id)
        "#{self.db_global_prefix}:#{id}"
      end

      def self.db_list
        "#{self.db_global_prefix}:#{self.db_list_prefix}"
      end

      # Queues are stored at the system level and are not specific
      # to a db. For example, new transactions to be processed are
      # stored in the queue called pending, regardless if they're
      # Transactions for service A or any other service.
      def self.queue_pending
        "#{self.system_prefix}:#{self.queue_pending_prefix}"
      end

      # Redefine this per class to store whatever information
      # is important to you
      def self.db_cache_info
        "#{self.class}"
      end

      ########################
      #   Instance Methods   #
      ########################

      # These are just copies to make them available to
      # instances.

      def global_prefix
        self.class.global_prefix
      end
      def db_prefix
        self.class.db_prefix
      end
      def db_id
        self.class.db_id(self.id)
      end

      def db_list
        self.class.db_list
      end

      def db_cache_info
        self.class.db_cache_info
      end

      def system_prefix
        self.class.system_prefix
      end

      def queue_pending_prefix
        self.class.queue_pending_prefix
      end

      def queue_pending
        self.class.queue_pending
      end

    end
  end
end
