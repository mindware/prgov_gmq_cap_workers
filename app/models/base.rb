module PRGMQ
  module CAP
    class Base
      # this class adds database functionality
      attr_accessor :id
      ########################
      #     Class Methods    #
      ########################

      # This method will be redefined by each child class
      def self.db_prefix
        ""
      end

      # The prefix to be used to store lists of this class
      def self.db_list_prefix
        "list"
      end

      # Redefine this per class to store whatever information
      # is important to you
      def self.db_cache_info
        "#{self.class}"
      end

      # Grabs the prefix from the storage,
      # adds this classes's db_prefix. This won't
      # need to be redefined by classes that
      # inherit this Base class.
      def self.db_global_prefix
        "#{Store.db_prefix}:#{self.db_prefix}"
      end

      # Displays the proper id for this object in the db
      def self.db_id(id)
        "#{self.db_global_prefix}:#{id}"
      end

      def self.db_list
        "#{self.db_global_prefix}:#{self.db_list_prefix}"
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

    end
  end
end
