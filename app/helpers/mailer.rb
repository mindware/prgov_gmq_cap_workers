require 'logger'
require 'mail'
require 'app/helpers/config'

module GMQ
	module Workers
		class Mailer

			# This method setups the mailer. At this time it simply
			# sets it up and returns true.
			# TODO IDEA: Ideally it should check if the mailer is available, and
			# return false if it isn't. We could do this by having a scheduled worker
			# that simply assesses the availability of the STMP server. The setup method
			# would check that, and if it fails, we don't send email.
			#      IDEA: We should also check if we're in downtime mode. At that time
			#            we shouldn't be sending emails and jobs should simply retry later
			def self.setup
						# Setup the Mailer
						Mail.defaults do
							delivery_method :smtp, {
															:address   	 => Config.all["system"]["smtp"]["host"],
															:port     	 => Config.all["system"]["smtp"]["port"],
															:user_name	 => Config.all["system"]["smtp"]["user"],
															:password 	 => Config.all["system"]["smtp"]["password"],
															:authentication       => 'plain',
															:enable_starttls_auto => true
							}
						end # end of mail.defaults
				return true
			end

			def self.mail(to, from, subject, text, html)

				puts "SENDING!!!!!\n\n"
				# if setup fails, return false
				return false if !self.setup
				# if any parameter is missing, return false
				return false if to.nil? or from.nil? or subject.nil? or text.nil? or html.nil?

				# TODO: later simply use the Resque logger.
		    log = Logger.new 'log/mailer.log'

		    data = { :to => "#{to}",
		             :from => Config.all["system"]["smtp"]["from"],
		             :subject => subject,
		             :text => text,
		             :html => html
		    }

		    log.debug "Starting to send email to #{data[:to]}"
		    result = self.send_mail(data)
		    log.debug "Email result: #{result}"
			end

		  def self.send_mail(data)
					# Send the email
				  mail = Mail.deliver do
				    to "#{data[:to]}"
				    from "#{data[:from]}"
				    subject "#{data[:subject]}"
				    text_part do
				      body "#{data[:text]}"
				    end
				    html_part do
				      content_type 'text/html; charset=UTF-8'
				      body "#{data[:html]}"
				    end
			   end # end of mail
			end # end of send method
		end # end of class
	end # end of module Workers
end # end of module GMQ
