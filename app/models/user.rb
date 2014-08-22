module PRGMQ
  module CAP
    class User
        attr_reader :username, :password, :application

        # users belong to an application of a remote system.
        # this class stores the credentials for such systems in memory. 
        def initialize(username, password, application)
          @name = username
          @application = application
          @password    = password
        end
    end
  end
end
