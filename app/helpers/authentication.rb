require 'digest/md5'

module PRGMQ
  module CAP
    class Authentication

        # class << self
        #     attr_reader :DB
        # end

        # This validates if a username and password combination are correct.
        # Retruns true if correct, false if not.
        def self.valid?(username=nil, password=nil)
            # puts "Authentication: '#{username}', '#{password}'" if Config.debug
            if(username.to_s.length == "" or password.to_s.length == "")
              return false
            end

            if(Config.users.has_key? username)
              # We currently require all password salts to be of length 24, based on
              # the tool generation we've provided's SecureRandom implementation
              # If this doesn't match, someone messed up a passkey manually.
              raise InvalidPasskeyLength if(Config.users[username]["passkey"].length < 24)
              salt = Config.users[username]["passkey"][0..23]
              secure_password = Config.users[username]["passkey"][24..-1]
              password = Digest::MD5.hexdigest(password + salt)
              if(password == secure_password)
                return true
              else
                return false
              end
            else
              return false
            end
        end

        # Finds a user by name. This is a user that has *already*
        # been authenticated by the system using basic_authentication.
        #
        # Since Grape can't store the credentials when it delegates
        # basic authentication to Rack, we must do this find here.
        # If we ever figure out how to save a result from the initial
        # http_basic, ie, by modifying the self.valid? method above
        # to return the User object, then we should simply send such
        # an object as a parameter to the following method. Unfortunately
        # perhaps as a result of lack of sleep, I haven't figured it out
        # in the last few hours (after 17 hours of straight coding) how to
        # do this safely taking into consideration we're running on Goliath
        # and there are fibers all over the place. Sue me. If you attempt it
        # please, don't step on the fibers. Thanks.
        def self.find_user(username=nil)
            return false if(username.to_s.length == "")
            # Fetch user
            if(Config.users.has_key? username)
                return User.new(username, Config.users[username]["groups"])
            else
              return false
            end
        end

    end
  end
end
