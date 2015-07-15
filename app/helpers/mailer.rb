require 'app/helpers/library'
require 'mail'
require 'app/helpers/config'

module GMQ
	module Workers
		class Mailer
			extend LibraryHelper
			# This method setups the mailer configuration.
			def self.setup
					# Setup the Mailer
					Mail.defaults do
						delivery_method :smtp, {
														:address   	 => Config.all["system"]["smtp"]["host"],
														:port     	 => Config.all["system"]["smtp"]["port"],
													#	:user_name	 => Config.all["system"]["smtp"]["user"],
													#	:password 	 => Config.all["system"]["smtp"]["password"],
													#	:authentication       => 'plain',
														:enable_starttls_auto => false
						}
						Config.logger.info "Using #{Config.all["system"]["smtp"]["host"]} as relay."
					end # end of mail.defaults
			end

		  # The new way to mail
			def self.mail_payload(payload)
				self.setup

				# if any required parameter is missing, return false
				if !payload.has_key?("to") or
					 !payload.has_key?("from") or
					 !payload.has_key?("subject") or
					 !payload.has_key?("text") or
					 !payload.has_key?("html")
							raise PRGov::IncorrectEmailParameters, "Invalid or missing arguments for mailer."
				end

				# if file_rename (custom name for attachment) and file_path (the path to
				# file) arent nil, read file and append the file data to the email:
				if (payload.has_key? "file_rename" and payload.has_key? "file_path")
					  # attempt to read the file from disk and add it to the payload
						payload["file_content"] = File.read(payload["file_path"])
				end
				Config.logger.info "Mailing #{payload["to"]}."
				# Commented out: this previous method doesn't handle multipart that swell, 
				# which means that while most mail services like gmail handle it well, mailers that 
				# aren't smarter, like yahoo fail. However, it properly sends html and text-based emails
				# while send_mail_attachment includes works great for attachment, but includes multi part data
				# on plain emails that suggests in some clients that it contains attachment when it doesnt. 
				# Eventually we could dive deeper and create a single method that properly handles both accounts
				# however, for now, as this is a quick fix that works properly, we comment
				# this, and use send_mail for non attachment payloads and send_mail_attachment for attachments. 
				#result = self.send_mail(payload)

				# Use our new method for sending proper multi part files and attachments
				if (payload.has_key? "file_rename" and payload.has_key? "file_path")
					result = self.send_mail_attachment(payload)
				else
					# use the regular send mail if no attachments
					result = self.send_mail(payload)
				end

				raise StandardError, "Could not send email payload" if !result
				Config.logger.info "Mailing done!"
				return true
			end

			# old method, do not use.
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
						# Set the charset
						charset = "UTF-8"
			    end # end of mail
					# empty the data payload
					data = nil
					true
			end # end of send method

			# Test:
			def self.send_mail_attachment(data)
					false if(!data.nil?)
					# Send the email

					# if any required parameter is missing, return false
					if !data.has_key?("to") or
						 !data.has_key?("from") or
						 !data.has_key?("subject") or
						 !data.has_key?("text") or
						 !data.has_key?("html")
								raise PRGov::IncorrectEmailParameters, "Invalid or missing arguments for mailer."
					end


					mail = Mail.new do |mail|
						to "#{data["to"]}"
						from "#{data["from"]}"
						subject "#{data["subject"]}"
						# Set the charset
						charset = "UTF-8"
					end

					# Create the text and html as separate mail parts
					text_body = Mail::Part.new do
						body "#{data["text"]}\n\n"
						content_type 'text/plain; '
					end

					html_body  = Mail::Part.new do
						body "#{data["html"]}"
						content_type 'text/html; charset=UTF-8'
					end

					# Create a mail part to hold the html and plain text
					bodypart = Mail::Part.new
					bodypart.text_part = text_body
					bodypart.html_part = html_body

					# Add the html and plain text to the email
					mail.add_part bodypart

					# after all is said an done, then we add the attachments
					if(data.has_key?("file_rename") and data.has_key?("file_content"))
						Config.logger.info "Using attachment."
						mail.add_file :filename => "#{data["file_rename"]}",
					 			:content => data["file_content"]
						 #mail.attachment[data["file_rename"]] = data["file_content"]
					end

					# send that email
					mail.deliver!

					# empty the data payload, save the planet
					data = nil
					true
			end # end of send method

		end # end of class
	end # end of module Workers
end # end of module GMQ
