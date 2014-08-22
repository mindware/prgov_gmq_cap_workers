# Andrés Colón Pérez - office of the CIO 2014
module PRGMQ
	module CAP
		module LibraryHelper

			def logger
				# This will return an instance of the Logger class from Ruby's
				# standard library. The standard logger class is Thread-safe, btw.
				Config.logger
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
			# This method is also the primary way for logging information.
			# As such, we don't return immediately if debug is false. We let the
			# system log properly, and skip display info if debug is false.
			def debug(str, use_title=false, use_prefix=true, log_type="info")s
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
				""
			end

			def last_transactions
				  Transaction.last_transactions
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
