# Andrés Colón Pérez - office of the CIO 2014
module PRGMQ
	module CAP
		module LibraryHelper

			# When this is called, the user has *already* been authenticated.
			# He had proper credentials to get into the API. Here we retrieve his
			# groups to check if he is able to access a resource only available to
			# allowed_groups.
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
			def add_visit
				Stats.add_visit
			end

			def total_visits
					visits = Stats.visits
					visits.nil? ? 0 : visits
			end

			# helper method to interact with Stats and get completed transactions
			def total_completed
					completed = Stats.completed
					completed.nil? ? 0 : completed
			end

			# Prints details if we're in debug mode
			def debug(str, use_title=false)
				  title = "DEBUG: " if use_title
				  puts "#{title}#{str}" if Config.debug
					logger.info str
			end
			#
			# def log(str)
			# 		puts "#{str}" if Config.logging
			# end

			def last_transactions
					last = Store.db.lrange(Transaction.db_list, 0, -1)
			end

			def request_info
				output = "Incoming Request Data:\n"+
				"User: #{env["REMOTE_USER"]} (#{env["REMOTE_ADDR"]})\n"+
				"URI: #{env["REQUEST_URI"]}\n"+
				"Time: #{Time.now.strftime("%m/%d/%Y - %r")}\n"
				if(env["api.request.input"].to_s.length > 0)
					 output << "JSON Payload:\n#{env["api.request.input"]}\n"
				end
				if(route.route_description.to_s.length > 0)
					 output << "Description:\n#{route.route_description}\n"
				end
				output << "Result:\n"
				return output
			end

			# Displays what we're returning to the client, to STDOUT.
			# Useful if we're debugging.
			def result(value)
				if(Config.display_results and Config.debug)
					if value.is_a? Grape::Entity
						 debug "#{value.to_json}"
					else
						debug value.to_s
					end
					# Then we proceed to allow the value to reach the user
					return value
				end
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
					else "in #{((a+180000)/(60*60*24*7) / 4).to_i.to_s} months"
				end
			end

		end
	end
end
