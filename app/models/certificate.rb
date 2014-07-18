# Model that can take a base64 file and dump it into a pdf
require 'base64'

module PRGMQ
	module CAP
		class Certificate
			include PRGMQ::CAP::LibraryHelper
			attr_accessor :file

			# Determines wether this certificate contains decoded data.
			def decoded?
				@decoded
			end

			# Check if the certificate ready to be used
			def ready?
				if decoded? and !@data.nil?
					true
				else
					false
				end
			end

			def dump(file)
				# if cert isn't ready, simply return false and deny this.
				false if !ready?
				begin
					puts "Saving decoded certifiate in #{file}"
					File.open(file, 'w') { |file| file.write(@data) }
					if validate_pdf(file)
						puts "Done."
						return true
					else
						puts "Invalid PDF...deleting #{file}"
						File.delete(file)
						return false
					end
				rescue Exception => e
					puts "Error: #{e}"
					return false
				end
			end


			def initialize(base64_file)
				load(base64_file)
			end

			def validate_pdf(file)
			  begin
				output = ""
				IO.popen(["file", "--brief", "--mime-type", file], in: :close, err: :close) { |io|
					output =  io.read.chomp
				}
				return true if output.to_s.downcase.include? "pdf"
			  rescue Exception => e
				puts "Error checking file type: #{e.backtrace.join("\n")}"
			  end
			end

			def load(file64)
				@file    = file64
				@decoded = false
				@data	 = nil
				# We trust this is a base64 as the API already did proper validations.
				# Let's trust our own code.
				temp = ""
				begin
					puts "Reading #{file64}..."
					File.open(file64, "r") do |f|
						  f.each_line do |line|
							temp << line
						  end
					end
					puts "Done."
				rescue Exception => e
					puts "Error: #{e}"
					return false
				end
				begin
					puts "Decoding base64 file in memory..."
					@data = Base64.decode64(temp)
					temp = ""
					# if it works, we mark this object as decoded
					@decoded = true
					puts "Done."
					return true
				rescue Exception => e
					puts "Could not decode the certificate, error: #{e}"
					return false
				end
			end # load end
		end # Certificate end
	end # CAP end
end # PRGMQ end
