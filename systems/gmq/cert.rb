$: << File.expand_path(File.dirname(__FILE__) +"/../../")

Dir.chdir "../../"
require "lib/dependencies"
# Dir["app/core/workers/*.rb"].each {|file| require file; puts "Loading #{file}" }

input = {"id" => "#{ARGV[0]}"}
klass = GMQ::Workers::CreateCertificate
worker = klass.new
klass.perform(input)
