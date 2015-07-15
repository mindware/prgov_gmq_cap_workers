# First, fix the paths so that everything under this directory
# is in the ruby path. This way we don't have to include relative filepaths

$: << File.expand_path(File.dirname(__FILE__) +"/../systems/prgov/")

puts "URL: #{File.expand_path(File.dirname(__FILE__) +"/../systems/prgov/")}"

Dir.chdir File.expand_path(File.dirname(__FILE__) +"/../systems/prgov/")

require './irb'

 GMQ::Workers::Mailer

puts "Preparing payload."
payload = {
          "from" => "noreply@pr.gov",
          #"to" => "levipr@gmail.com",
          "to" => "mindware07@yahoo.com",
          "subject" => "Esto es una prueba",
          "text" => "Aqui su certificado.\n\n",
          "html" => "<html><body><b>Aqui su certificado.</b></br></body></html>",
	  "file_rename" => "certificado.pdf",
          "file_path" => "/home/gmq/prgov/cap_workers/files/pdf/PRCAP1189653163449951595.pdf"
}

payload["file_content"] = File.read(payload["file_path"])

GMQ::Workers::Mailer.setup
GMQ::Workers::Mailer.send_mail_attachment(payload)
#puts GMQ::Workers::Mailer.methods
puts "Mailing done."

