# First, fix the paths so that every scripts used by this test is properly found and
# is in the ruby path. This way we don't have to include relative filepaths
$: << File.expand_path(File.dirname(__FILE__))

require 'json'
require 'rest_client'
# include all helpers - since the scripts are ran under us, we take their path
# into consideration, and so an additiona ../
require "../../../app/helpers/library" 
Dir["../../../app/helpers/*.rb"].each {|file| require file } 

include PRGMQ::CAP::LibraryHelper	# General Helper Methods

class Rest

  attr_accessor :user, :pass, :credentials, :url, :payload, :method, :type

  def to_curl
    str = "curl "
    str << "-u #{user}:#{pass} " if !user.nil? and !pass.nil?
    str << '-H "Content-Type: application/json" ' if type.to_s == "json"
    str << "-d '#{payload.to_json}' " if payload.to_s.length > 0
    str << "-X "
    str << "PUT "     if method.to_s == "put"
    str << "POST "    if method.to_s == "post"
    str << "GET "     if method.to_s == "get"
    str << "DELETE "  if method.to_s == "delete"
    str << url
  end

  def request
     begin
         site =  url.gsub("https://", "https://#{credentials}@")
         site = site.gsub("http://", "http://#{credentials}@")
         puts "URL:\n#{site}\n\n"
         puts "CURL:\n#{self.to_curl}\n\n"
         puts "Requested:\n#{payload.to_json}\n\n"
         response = RestClient.send method, site, payload.to_json,
                                          :content_type => :json,
                                          :accept => :json
         puts "HTTP Code:\n#{response.code}\n\n"
         puts "Headers:\n#{response.headers}\n\n"
         puts "Result:\n#{response.gsub(",", ",\n").to_str}\n"
     rescue Exception => e
         puts e.inspect.to_s
     end
  end

  def initialize(url, user, pass, type, payload, method)
     @user = user
     @pass = pass
     @credentials = "#{user}:#{pass}"
     @url = url
     @payload = payload
     @method = method
     @type = type
  end

end
