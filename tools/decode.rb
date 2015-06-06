require 'base64'

if ARGV.length == 2
	file = ARGV[0]
	base64 = ARGV[1]
elsif ARGV.length == 1
	base64 = ARGV[0]	
	puts "No filename provided as first argument. Using 'cert.pdf'."
	file = "cert.pdf"
else
	puts "Please pass a base64 as parameter. ruby decode.rb <base64>"
	exit
end

puts "Trying to decode the base64 data" 

begin
	data = Base64.decode64(base64)
rescue Exception => e
	puts "Invalid base64 (error #{e})."
	exit
end

puts "Writing data..."
begin 
	File.open(file, 'w') { |file| file.write(data) }
	puts "Done."
rescue Exception => e
	puts "Error #{e}."
end
