require 'app/helpers/library'
require 'mail'
require 'app/helpers/config'

module GMQ
	module Workers
		class Mailer
			extend LibraryHelper
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
							Config.logger.info "Using #{Config.all["system"]["smtp"]["host"]} as relay."
						end # end of mail.defaults
				return true
			end

		  # The new way to mail
			def self.mail_payload(payload)
				# if setup fails, return false
				return false if !self.setup
				# if any required parameter is missing, return false
				return false if !payload.has_key?("to") or
												!payload.has_key?("from") or
												!payload.has_key?("subject") or
												!payload.has_key?("text") or
												!payload.has_key?("html")

				# if file_rename (custom name for attachment) and file_path (the path to
				# file) arent nil, read file and append the file data to the email:
				if (payload.has_key? "file_rename" and payload.has_key? "file_path")
					  # attempt to read the file from disk and add it to the payload
						payload["file_content"] = File.read(payload["file_path"])
				end
				result = self.send_mail(payload)
				raise StandardError, "Could not send email payload" if !result

			end

			def self.mail(to, from, subject, text, html, file_rename=nil, file_path=nil)
				# puts "SENDING!!!!!\n\n"
				# if setup fails, return false
				return false if !self.setup
				# if any parameter is missing, return false
				return false if to.nil? or from.nil? or subject.nil? or text.nil? or html.nil?

				# TODO: later simply use the Resque logger.
		    # log = Logger.new 'log/mailer.log'

		    data = { :to => "#{to}",
		             :from => Config.all["system"]["smtp"]["from"],
		             :subject => subject,
		             :text => text,
		             :html => html
		    }

				# if file_rename (custom name for email) and file_path (actual path to
				# file) arent nil, append them to data:
				if file_rename.to_s.length > 0 and file_path.to_s.length > 0
						data[:file_content] = File.read(file_path)
						data[:filename] = file_rename
				end

		    # log.debug "Starting to send email to #{data[:to]}"
		    result = self.send_mail(data)
		    # log.debug "Email result: #{result}"
			end

		  def self.send_mail(data)
					false if(!data.nil?)
					logger.info "Mailing #{data}"
					# Send the email
				  mail = Mail.deliver do
				    to "#{data["to"]}"
				    from "#{data["from"]}"
				    subject "#{data["subject"]}"
				    text_part do
				      body "#{data["text"]}"
				    end
				    html_part do
				      content_type 'text/html; charset=UTF-8'
				      body "#{data["html"]}"
				    end
						if(data.has_key?("file_rename") and data.has_key?("file_content"))
							add_file :filename => "#{data["file_rename"]}",
											 :content => data["file_content"]
						end
			    end # end of mail
					# empty the data payload
					data = nil
					true
			end # end of send method
		end # end of class
	end # end of module Workers
end # end of module GMQ