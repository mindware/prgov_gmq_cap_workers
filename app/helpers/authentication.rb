require 'digest/md5'

module GMQ
  module Workers
    class Authentication

        # Finds a user by system name
        # Worker's users.json saves credentials for systems,
        # in the form of: "system_name":{ "username":"guest","password": "123"}
        def self.find_user(system=nil)
            return false if(system.to_s.length == "")
            # Fetch user
            if(Config.users.has_key? system)
                return User.new(Config.users[system]["username"],
                                Config.users[username]["password"])
            else
              return false
            end
        end

    end
  end
end
