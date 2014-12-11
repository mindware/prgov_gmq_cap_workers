require 'logger'
require 'app/helpers/errors'
require 'app/helpers/colorize'
require 'json'

module GMQ
  module Workers
      class Config

          class << self
              attr_reader :all,              # holds configurations in memory
                          :backtrace_errors, # determines if we print backtrace
                          :debug,   # This tells us if we're in debugging mode
                          :downtime,# determines if we're in maintainance
                          :logging, # determines if we're logging
                          :logger,   # returns the logger object. STDOUT if not logging
                          :display_hints # prints out hints to console, such as API
                                         # resource descriptions & DB commands.
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

          # This variable will be loaded from system.json. It will tell us
          # if we're in debug which results in more information being logged.
          @debug = false
          # Sets backtrace for unexpected exceptions,
          # works only if debug is true.
          @backtrace_errors = false
          @logging = true
          # variable that determines if we're down for maintenance.
          @downtime = false
          @display_hints = false

          # Gets the current environment (production, development, testing)
          # from the Webserver. At this time, we use Goliath for its awesome
          # asynchronous EM capabilities.

          def self.environment
            if(@all["system"].has_key? "environment")
               return @all["system"]["environment"]
            else
              # By default if we can't determine our environment,
              # we'll go into production mode. This could happen if the
              # system.json doesn't contain an environment field.
              return "production"
            end
          end

          # This determines the log file
          # For alternative configuration see:
          # http://www.ruby-doc.org/stdlib-2.1.2/libdoc/logger/rdoc/Logger.html
          # This returns our logger. If the system is configured to log, we
          # use our logging strategy. If not, we
          def self.logger
            # Our logging strategy: In order to make sure we don't
            # store more than the given amount of space we've been
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
              Logger
            end
          end

          # Returns the entire config for users. Used for authentication
          # so this hash will contain passkey. Tread lightly.
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

          # a simple check to see if the configuration is already loaded
          # in memory. If its not, load it. If it is, return true.
          def self.check
              # here we check if the config is already loaded in memory
              if @all.nil?
                if(load_config)
		              # Once the configuration is loaded, print some info to STDOUT
                  if @debug
                      puts "Loading configuration files into memory: "+
                       "#{@all.keys.join(", ").to_s}"
            		      puts "Stored credentials: #{@all["users"].keys.join(", ")}"
            		      print "System settings:"# if @debug
                		  list = ""
                		  @all["system"].each do |key, value|
                          # if we have a hash inside the hash
                          if value.class == Hash
                             list << " #{key.green} -> "
                             value.each do |k, v|
                               if k.to_s.downcase == "password"
                                  list << " #{k}: #{"<not shown>".gray}"
                               else
                                  list << " #{k}: #{v.to_s.bold.cyan},"
                               end
                             end
                          else
                			         list << " #{key.green}: #{value.to_s.bold.green},"
                          end
                		  end
                		  # print the list, but remove the last character (,)
                		  puts list.chop.scan(/.{1,151}/m)
                		  list = ""
                  end
                end
              end
              return true
          end

          # This method loads config files into memory.
          def self.load_config
               @all = {
                           "users"   => load_config_file(CONFIG_USER),
                           "db"      => load_config_file(CONFIG_DB),
                           "system"  => load_config_file(CONFIG_SYSTEM)
               }
               unless @all["system"]["debug"].nil?
                  @debug = @all["system"]["debug"]
               end
      	       # Backtrace is always false, unless we're in debug mode and
               # its explicitely on
      	       if @debug == true
                  if !@all["system"]["backtrace_errors"].nil?
                      @backtrace_errors = @all["system"]["backtrace_errors"]
                  end
      	       else
      	       	  @backtrace_errors = false
  		            @all["system"]["backtrace_errors"] = false
      	       end
               unless @all["system"]["logging"].nil?
                  @logging   = @all["system"]["logging"]
               end
               unless @all["system"]["downtime"].nil?
                  @downtime  = @all["system"]["downtime"]
               end
               unless @all["system"]["display_certificates"].nil?
                   @display_certificates = @all["system"]["display_certificates"]
               end
               @display_hints = @all["system"]["display_hints"] unless @all["system"]["display_hints"].nil?
               # Determines wether we print out to STDOUT what we send to our
               # clients. So, with this, you can see in the console the HTTP
               # result sent to clients.
               unless @all["system"]["display_results"].nil?
                  @display_results = @all["system"]["display_results"]
               end
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

          # Returns the database we're going to be connecting to.
          # The redis database number we're connecting to. Redis uses
          # numbered database (instead of database names) to distinguish
          # on which database you're working on. This can be specified in
          # the projects root's config folder, in tehe file db.json, by
          # adding a key and value to each database server config, such as:
          # "db_id"    : 0
          def self.db_id
              if(@all["db"].has_key? "db_id")
                 @all["db"]["db_id"]
              else
                 # by default, use database number 0 for redis unless
                 # specified.
                 0
              end
          end

          # Returns the password we're going to use to connect to redis
          def self.db_password
              # later change this so that we use the port
              # of the current db_host, when we add iteration
              # in case of failure
              index = @all["db"]["servers"].keys[0]
              if(@all["db"]["servers"][index].has_key? "password")
                 @all["db"]["servers"][index]["password"]
              else
                 # by default, send an empty password.
                 ""
              end
          end
      end
  end
end
