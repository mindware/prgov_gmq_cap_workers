$: << File.expand_path(File.dirname(__FILE__) +"/../../")

Dir.chdir "../../"
require "lib/dependencies"
# Dir["app/core/workers/*.rb"].each {|file| require file; puts "Loading #{file}" }
puts "This assumes the pdf file is already generated in order to attempt to email it."
input = {"id" => "#{ARGV[0]}", "text" => "This is the certificate.", "html" => "This is the certificate.",
	 "file_path" => "/tmp/gmq/files/pdf/#{ARGV[0]}.pdf", "file_rename" => "certificado.pdf" }
klass = GMQ::Workers::FinalEmailWorker
worker = klass.new
klass.perform(input)
