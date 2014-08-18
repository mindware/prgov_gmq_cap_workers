require 'json'

module PRGMQ
  module CAP
      class Config

          class << self
              attr_reader :all,   # holds configurations in memory
                          :backtrace_errors, # determines if we print backtrace
                          :debug, # This tells us if we're in debugging mode
                          :users, # class method to grab user config from @all
                          :downtime,# determines if we're in maintainance
                          :logging, # determines if we're logging
                          :logger,  # returns the logger object. STDOUT if not logging
                          :system,  # class method that returns system config in @all
                          :display_results, # shows what we return to client, in console
                          :display_certificates # prints out base64 data to console
              attr_writer :downtime # This setter lets us go into maintainance mode
          end


          # General Class Defaults
          # This will be overwritten when the configuration loads.
          @all = nil

          # We define constants for the configuration
          CONFIG_DIR    = "config"
          CONFIG_USER   = "#{CONFIG_DIR}/users.json"
          CONFIG_DB     = "#{CONFIG_DIR}/db.json"
          CONFIG_SYSTEM = "#{CONFIG_DIR}/system.json"

          # if Goliath is defined
          if(Object.const_defined?('Goliath'))
            # Set debug to true if we're in development mode.
            @debug = (Goliath.env.to_s == "development")
          else
            # puts "WARNING: Config could not determine current environment "+
            #      "from Webserver. Are we not using Goliath? This will affect "+
            #      "API's Config.environment method for checking environment and "+
            #      "displaying debugging information. For now, we'll default "+
            #      "into 'production' for safety. If you're not running the "+
            #      "actual webserver, you can ignore this message, otherwise "+
            #      "if you are, this needs fixing if you ever want to see "+
            #      "debugging information! Please look into it."
            warn "Info: This script doesn't appear to be running in a "+
                 "Goliath webserver environment. See app/helpers/config.rb "+
                 "for commented information."
            @debug = false
          end

          # Sets backtrace for unexpected exceptions,
          # works only if debug is true.
          @backtrace_errors = false
          @logging = true
          # variable that determines if we're down for maintenance.
          @downtime = false
          # Determines wether we print out to STDOUT what we send to our
          # clients. So, with this, you can see in the console the HTTP
          # result sent to clients.
          @display_results = false
      	  # variable that determines if incoming base64 certs are displayed in
      	  # console and logged.
      	  @display_certificates = false

          # Gets the current environment (production, development, testing)
          # from the Webserver. At this time, we use Goliath for its awesome
          # asynchronous EM capabilities.

          def self.environment
            if(Object.const_defined?('Goliath'))
               return Goliath.env.to_s
            else
              # By default if we can't determine our environment,
              # we'll go into production mode. This could happen if someone
              # changed our webserver from Goliath to some other wordly
              # webserver. We'll need a way to get the current environment
              # from that webserver.
              puts "Config was unable to determine webserver environment. "+
                   "Auto-selecting production mode."
              return "production"
            end
          end

          # This determines the log file
          # For alternative configuration see:
          # http://www.ruby-doc.org/stdlib-2.1.2/libdoc/logger/rdoc/Logger.html
          # This returns our logger. If the system is configured to log, we
          # use our logging strategy. If not, we
          def self.logger
            # @logger ||= Logger.new('logs/foo.log', 'daily')
            # Taking into considerations daily backups at unknown hours, we
            # could use the weekly option for now and reduce it only if it
            # turns out log files in a week become too huge, with the following:
            # @logger ||= Logger.new('logs/foo.log', 'weekly')

            # Our logging strategy:
            # Alternative to the strategies outlined above, in order to make
            # sure we don't store more than the given amount of space we've been
            # provided, we have a logging strategy with a maximum log retention
            # and maximum log space (max bytes). For example, we could have
            # have a maximum amount of 10 logs, of a maximum size of 10mb.
            # Doing this, we could store a maximum of 100MB of logs.
            # These settings are set in the systems configuration file
            # (ie: config/systems.json)
            if @logging and !@all.nil?
              @logger ||= Logger.new("logs/#{self.environment}.log",
                                     @all["system"]["logs_max_retention"],
                                     @all["system"]["logs_max_bytes"])
            else
              # If we're not logging, we default to STDOUT.
              API.logger
            end
          end

          # Returns the entire config for users. Used for authentication
          # so this hash will contain passkeys. Tread lightly.
          def self.users
            # Make sure the server's config is loaded. Loads it if it isn't.
            self.check
            # @all["users"] = nil
            return @all["users"] if @all.has_key? "users"
            # if for some reason it doesn't exist, and no users exist,
            # so lets create the empty list in memory.
            @all["users"] = {}
            return @all["users"]
          end

          def self.groups
            # Make sure the server's config is loaded. Loads it if it isn't.
            self.check
            if @all.has_key? "users"
               # we'll temporary save all the groups found in the config here
               groups = []
               # if the config has a users hash
               if (@all["users"].length > 0)
                   # iterate through the users hash
                   @all["users"].each do |name, key|
                       # if the user has groups key
                       if(key.has_key? "groups")
                         if(key["groups"].is_a? Array)
                           # grab the groups array from the hash
                           groups << key["groups"]
                         else
                           # user doesn't have a security group as an array
                           # ['sijc', 'webapp'] etc, but something else.
                           raise InvalidConfigFile
                         end # end of check if groups is an Array
                       else
                         # user doesn't have a security group
                         raise InvalidConfigFile
                       end # end of check if user has security group
                   end # end of iteration through users

                   # create a unique list of security groups and sort them
                   groups = groups.flatten.uniq.sort
               end
               # don't go past this point, since we had something in the config
               return groups
            end
            # if for some reason it doesn't exist, and no users exist,
            # so lets create the empty list in memory.
            @all["users"] = {}
            # Now return an empty list of security groups
            return []
          end

          # a simple check to see if the configuration is already loaded
          # in memory. If its not, load it. If it is, return true.
          def self.check
              # here we check if the config is already loaded in memory
              if @all.nil?
                if(load_config)
		              # Once the configuration is loaded, print some info to STDOUT
                  puts "Loading configuration files into memory: #{@all.keys.join(", ").to_s}"
            		  puts "Allowed users: #{@all["users"].keys.join(", ")}" if @debug
            		  print "System settings:"# if @debug
            		  list = ""
            		  @all["system"].each do |key, value|
            			list << " #{key.green}: #{value.to_s.bold.green},"
            		  end
            		  # print the list, but remove the last character (,)
            		  puts list.chop.scan(/.{1,151}/m)  #if @debug
            		  list = ""
                end
              end
              return true
          end

          # This method loads config files into memory.
          # this can be called at runtime by administrators, to force the
          # server to upade configuration, without requiring a restart.
          def self.load_config
               # This is a system for systems. Since it's not designed to have
               # a dynamic amount of users registering, mainly applications
               # we won't be doing round trips to check for users in a db,
               # as that will introduce latency into the system. Instead
               # we'll have a file in a trusted directory, with salted/hashed
               # password and a tool to generate passwords for these users,
               # and the configurations will be in local memory, making it
               # very fast to check configurations and perform authentication,
               # without network roundtrips.
               user_config   = load_config_file(CONFIG_USER)
               db_config     = load_config_file(CONFIG_DB)
               system_config = load_config_file(CONFIG_SYSTEM)
               @all = {
                           "users"   => user_config,
                           "db"      => db_config,
                           "system"  => system_config
               }
               # clean up memory
               user_config, db_config, system_config = nil,nil, nil
               @debug     = @all["system"]["debug"]  unless @all["system"]["debug"].nil?
      	       # Backtrace is always false, unless we're in debug mode and its explictely on
      	       if @debug == true
                     	@backtrace_errors = @all["system"]["backtrace_errors"] if !@all["system"]["backtrace_errors"].nil?
      	       else
      	       	@backtrace_errors = false
  		          @all["system"]["backtrace_errors"] = false
      	       end
               @logging   = @all["system"]["logging"] unless @all["system"]["logging"].nil?
               @downtime  = @all["system"]["downtime"] unless @all["system"]["downtime"].nil?
               @display_certificates = @all["system"]["display_certificates"] unless @all["system"]["display_certificates"].nil?
               # Determines wether we print out to STDOUT what we send to our
               # clients. So, with this, you can see in the console the HTTP
               # result sent to clients.
               @display_results = @all["system"]["display_results"] unless @all["system"]["display_results"].nil?
               return true
          end

          # Catches any errors from get_json_from_file and appends
          # information about the specifics of the file to any errors.
          # If we ever migrated from JSON config files into something different
          # we could update this function and transform it to what load_config
          # expects.
          def self.load_config_file(file)
            begin
              get_json_from_file(file)
            rescue InvalidConfigFile
              raise $!, "Invalid configuration in #{file} file (#{$!})", $!.backtrace
            rescue MissingConfigFile
              raise $!, "Missing configuration in #{file} file (#{$!})", $!.backtrace
            end
          end

        	# Returns the JSON contents of the file.
        	def self.get_json_from_file(file)
            begin
          		# where we'll store our data
          		data = ""
          		# open the file to get the contents
              # if it doesn't exist, it'll error out and we'll catch it.
          		file = File.new(file, "r")
          		# read the file and load up the data within it to memory
          		file.each do |line|
          			# read each line
          			data << line
          		end
          		# close the file, since we're done for now
          		file.close()
              rescue Exception => e
                # When in doubt, print errors.
                raise MissingConfigFile
              end
              begin
          		# convert the data to JSON:
        			data = JSON.parse(data)

              rescue Exception => e
                # When in doubt, print errors.
                raise InvalidConfigFile
              end
        		return data
        	end

          def self.db_name
            # later change this so that we iterate through
            # all the servers should one fail, we try the next one
            index = @all["db"]["servers"].keys[0]
          end

          def self.db_pool_size
            # this is the pool size for connections
            if(@all["db"].has_key? "pool_size")
               @all["db"]["pool_size"]
            else
              2
            end
          end

          # Selects which db host to connect to
          # later we could iterate through the hosts found in db.
          def self.db_host
              # later change this so that we iterate through
              # all the servers should one fail, we try the next one
              index = @all["db"]["servers"].keys[0]
              @all["db"]["servers"][index]["host"]
          end

          # Selects the port baed on the host we're connecting to.
          def self.db_port
              # later change this so that we use the port
              # of the current db_host, when we add iteration
              # in case of failure
              index = @all["db"]["servers"].keys[0]
              @all["db"]["servers"][index]["port"]
          end

          def self.db_driver
              # First we choose the driver. By default we use the synchrony one.
              # If we weren't running on Eventmachine, we'd use a different one
              # such as hiredis. Let's check if the db settings has a driver
              # specified.
              if(@all["db"].has_key? "driver")
                 @all["db"]["driver"].to_sym
              else
                 :synchrony
              end
          end
      end
  end
end

# If we ever recode this module, remove the global variables and use
# accessible methods for each of the global variables. No more @debugging
# instead we use something like: def debugging @all["system"]["debug"] end
