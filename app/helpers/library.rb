# Andrés Colón Pérez - office of the CIO 2014
module PRGMQ
	module CAP
		module LibraryHelper

			# When this is called, the user has *already* been authenticated.
			# He had proper credentials to get into the API. Here we retrieve his
			# groups to check if he is able to access a resource only available to
			# allowed_groups.
			# After we determine if the user is allowed the resource or not we
			# either return the user's id, or we raise an exception.
			def allowed?(allowed_groups)
				# we grab the current user from the environment. This is after
				# said user has passed the scrutiny of a basic authentication.
				user = Authentication.find_user(env["REMOTE_USER"])
				# User should exist because we passed basic_auth to get here,
				# but just in case it got deleted after we got acess, throw an error:
				raise InvalidCredentials if (!user)
				# Check if the user is allowed into the specified groups
				# we do this by checking the intersection of both arrays
				if(!(user.groups & allowed_groups).empty?)
						return user
				else
						raise InvalidAccess
				end
			end


			# As this is not priority, this is not implemented at this time:
			# This is a security measure that could be implemented over Grape API's
			# present method. The present method is used by Grape in order to allow
			# Grape Entities to show specific parts of an object in a json format.
			# Present allows us to send variables to Grape Entities before they
			# are rendered, and Grape Entities allows us to use those parameters to
			# determine if we want to show a property of the object or not. This
			# is typically used when you want to restrict some property from an
			# object from being displayed if X variables is present.
			# However, when we have to do checks for multiple types of variables
			# for a single property, the entity code becomes quite complex and ugly
			# quickly. In order to keep things more simple, and allow our API to
			# restrict which groups of users can see which properties, we're could
			# create entities for the different groups.
			# For example: in the ../entities/ folder
			# We could have entity classes defined, such as "TransactionSIJC",
			# "TransactionWorkers", etc.
			#
			# The show method will automate the process of selecting the right
			# entity depending on the group the user belongs to. Since a user
			# can belong to multiple groups, we'll check the groups by highest access
			# first, in a descending order. We'll use the security group that
			# grants the most visibility first.
			#
			# Commented out for now, as it is low priority at this time, and we won't
			# need to replace the 'present' methods in the API any time soon.
			# In the future, we if we need more fine grained control of what an
			# admin sees, vs what progv, workers and other agencies see, we should
			# could implement this easily.
			# def show
			# 	# The entity    # which group only has access to it
			# 	#entities = {
			#                 "TransactionSIJC" => [sijc"],
			#								  "TransactionCreate" => ["prgov"]
			#									}
			#   # Here check the current user's groups
			#   # and show only the highest transction entity that he has access to.
			# end

			def logger
				# This will return an instance of the Logger class from Ruby's
				# standard library. The standard logger class is Thread-safe, btw.
				Config.logger
				# API.logger.new('foo.log', 10, 1024000)
				# Grape::API.logger = Logger.new(File.expand_path("../logs/#{ENV['RACK_ENV']}.log", __FILE__))
			end

			def user_list
					Config.users.keys
			end

			def security_group_list
					Config.groups
			end

			# tells the stats to add a visit
			def add_visit(db_connection=nil)
				Stats.add_visit(db_connection)
			end

			# tells the stats to add a visit
			def add_pending(db_connection=nil)
				Stats.add_pending(db_connection)
			end

			def remove_pending(db_connection=nil)
				Stats.remove_pending(db_connection)
			end

			# tells the stats to add a visit
			def add_completed(db_connection=nil)
				Stats.add_visit(db_connection)
			end

			# get totals from stats
			def total_pending(db_connection=nil)
				pending = Stats.pending(db_connection)
				pending.nil? ? 0 : pending
			end

			# get totals from stats
			def total_visits(db_connection=nil)
					visits = Stats.visits(db_connection)
					visits.nil? ? 0 : visits
			end

			# helper method to interact with Stats and get completed transactions
			def total_completed(db_connection=nil)
					completed = Stats.completed(db_connection)
					completed.nil? ? 0 : completed
			end

			# Prints details if we're in debug mode
			def debug(str, use_title=false, use_prefix=true, log_type="info")
				  title = "DEBUG: "   if use_title
					prefix = str_prefix.brown	if use_prefix
				  # print to screen
				  # puts "#{title}#{str}" if Config.debug
				  # strip of colors and log each line
					str.split("\n").each do |line|
						puts "#{prefix}#{title}#{line}" if Config.debug
						case log_type
							when "warn"
									 logger.warn "#{prefix}#{line}".no_colors
							when "error"
									 logger.error "#{prefix}#{line}".no_colors
							when "fatal"
									 logger.fatal "#{prefix}#{line}".no_colors
							else
									 logger.info "#{prefix}#{line}".no_colors
						end
					end
			end

			def warn(str)
				debug(str, false, true, "warn")
			end

			def fatal(str)
				debug(str, false, true, "fatal")
			end

			def error_msg(str)
				debug(str, false, true, "error")
			end

			# Used to define prefixes for strings, useful for prepending strings
			# when logging on an API.
			def str_prefix
				# if Object.const_defined?("env")
				# puts self.class.to_s.include? "Grape"
				if self.class.to_s.include? "API" or self.class.to_s.start_with? "Grape"
					# If we have a visit id assigned
					return "#{(env["VISIT_ID"].to_s.strip.length > 0 ? "#{env["VISIT_ID"]}: " : "") }"
				else
					return ""
				end
			end

			# def log(str)
			# 		puts "#{str}" if Config.logging
			# end

			def last_transactions
				  Transaction.last_transactions
			end

			def request_info
				output = "Incoming Request Data:\n"+
				"User: #{env["REMOTE_USER"].bold.yellow} (#{env["REMOTE_ADDR"].cyan})\n"+
				"URI: #{env["REQUEST_URI"].bold.blue}\n"
				output << "Method: "
        case env["REQUEST_METHOD"]
             when "PUT"
                   output << env["REQUEST_METHOD"].bold.cyan
							     output << " (Update)"
             when "DELETE"
                   output << env["REQUEST_METHOD"].bold.red
             when "GET"
                   output << env["REQUEST_METHOD"].bold.green
             when "POST"
                   output << env["REQUEST_METHOD"].bold.magenta
							     output << " (Create)"
             else
                   output << env["REQUEST_METHOD"].bold.yellow
        end
				output << "\n"+
				#"#{env.inspect}\n"+
				"Time: #{Time.now.strftime("%m/%d/%Y - %r")}\n"
				if(env["api.request.input"].to_s.length > 0)
					 output << "Incoming JSON Payload:\n"
					 payload = env["api.request.input"]
					 # For those request that contain certificates
					 # we truncate them out of the console
					 # in order to skip logging the base64 cert
					 # saving disk space.
					 if payload.include? "certificate_base64" and !Config.display_certificates
						# create a hash out of the payload
					 	payload = JSON.parse(env["api.request.input"])
						# change the value of the cert key
						payload["certificate_base64"] = "[Not shown per System Configuration]"
						# change it back to a json string
						payload = payload.to_json.to_s
					 end
					 # color the output based on the http method
					 case env["REQUEST_METHOD"].strip
						 when "PUT"
						 	output << payload.bold.cyan
						 when "DELETE"
						 	output << payload.bold.red
						 when "GET"
						 	output << payload.bold.green
						 when "POST"
						 	output << payload.bold.magenta
						 else
						 	output << payload.bold.yellow
					 end
					output << "\n"
				end
				if(route.route_description.to_s.length > 0)
					 output << "Description:\n#{route.route_description}\n"
				end
				output << "#{"Result".bold.cyan}:\n"
				return output
			end

			# Displays what we're returning to the client, to STDOUT.
			# Useful if we're debugging.
			def result(value)
				if(Config.display_results and Config.debug)
					if value.is_a? Grape::Entity
						 debug "#{value.to_json}"
					else
						# show the result as it'll be sent to the user by the API
						debug value.to_json.to_s
					end
				end
				# Then we proceed to allow the value to reach the user
				return value
		  end

			# expects seconds, returns pretty string of how long ago event happened
		  def ago(seconds)
		    a = seconds
		    case a
		      when 0 then "just now"
		      when 1 then "a second ago"
		      when 2..59 then a.to_s+" seconds ago"
		      when 60..119 then "a minute ago" #120 = 2 minutes
		      when 120..3540 then (a/60).to_i.to_s+" minutes ago"
		      when 3541..7100 then "an hour ago" # 3600 = 1 hour
		      when 7101..82800 then ((a+99)/3600).to_i.to_s+" hours ago"
		      when 82801..172000 then "a day ago" # 86400 = 1 day
		      when 172001..518400 then ((a+800)/(60*60*24)).to_i.to_s+" days ago"
		      when 518400..1036800 then "a week ago"
		      else ((a+180000)/(60*60*24*7)).to_i.to_s+" weeks ago"
		    end
		  end

			# expects seconds, returns pretty string of expected time
			def time_from_now(a)
				# where a is seconds
				case a
					when -1 then "never"
					when 0 then "just now"
					when 1 then "in one second"
					when 2..59 then "in #{a.to_s} seconds"
					when 60..119 then "in a minute" #120 = 2 minutes
					when 120..3540 then "in #{(a/60).to_i.to_s} minutes"
					when 3541..7100 then "in an hour" # 3600 = 1 hour
					when 7101..82800 then "in #{((a+99)/3600).to_i.to_s} hours"
					when 82801..172000 then "in one day" # 86400 = 1 day
					when 172001..518400 then "in #{((a+800)/(60*60*24)).to_i.to_s} days"
					when 518401..1036800 then "in a week"
					when 1036801..2433600 then "in #{((a+180000)/(60*60*24*7)).to_i.to_s} weeks"
					else "in #{((a+180000)/(60*60*24*7) / 4).to_i.to_s} month(s)"
				end
			end

		end
	end
end
