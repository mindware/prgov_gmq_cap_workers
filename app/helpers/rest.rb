require 'json'
require 'uri'
require 'rest_client'

# require "../../../app/helpers/library"
# Dir["../../../app/helpers/*.rb"].each {|file| require file }
#
# include GMQ::Workers::LibraryHelper	# General Helper Methods

# This class allows us to perform RESTful requests against APIs.
module GMQ
  module Workers
    class Rest

      attr_accessor :user,        # username
                    :pass,        # pass
                    :credentials, # a combination of user/pass in HTTP BASIC
                    :url,         # the original uri
                    :payload,     # header payloads, such as JSON for put/posts
                    :method,      # HTTP Method (get, put, post, delete, etc)
                    :type,        # the content type, text/html, json, etc.
                    :site         # the actual uri used, combined auth + url

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

      # TODO: this could fail if internet is down, we removed
      # the begin/rescue to see the errors that are thrown our way.
      def request
            #  puts "URL:\n#{site}\n\n"
            #  puts "CURL:\n#{self.to_curl}\n\n"
            #  puts "Requested:\n#{payload}\n\n"

            # An exception can ocurr here, ie for 401, 400, etc.
            # Any system that uses this library should catch those.
            # response = RestClient.send method, site, payload,
            #                                   :content_type => type.to_sym,
            #                                   :accept => :json

            case method
              when "get"
                # response = RestClient.get site, :content_type => type
                response = RestClient.send method, @site
              # when "post"
                # response = RestClient.post site, payload, :content_type => type,
                #                            :accept => :json
              # when "put"
                # response = RestClient.put site, payload, :content_type => type,
                #                            :accept => :json
              # when "delete"
                # response = RestClient.delete site, payload,
                #                            :content_type => type
            else
              # If we ever try to use an HTTP method that we haven't added
              # support for, raise a proper error so we're reminded to code it.
              raise RuntimeError, "Unsupported HTTP method (#{@method}) for "+
                                  "GMQ::Workers::Rest"
            end
            #  puts "HTTP Code:\n#{response.code}\n\n"
            #  puts "Headers:\n#{response.headers}\n\n"
            #  puts "Result:\n#{response.gsub(",", ",\n").to_str}\n"
            return response
            #  puts e.inspect.to_s
      end

      def initialize(url, user, pass, type, payload, method)
         @user = user
         @pass = pass
         # If a user or password has been supplied, we
         # create a valid basic auth string
         if @user.to_s.length > 0 or @pass.to_s.length > 0
            @credentials = "#{user}:#{pass}"
         else
            @credentials = nil
         end
         @url = url
         @payload = payload
         @method = method
         @type = type.to_sym
         # make sure we add the credentials for the basic auth
         # if any have been supplied
         if @credentials.to_s.length > 0
           @site =  @url.gsub("https://", "https://#{credentials}@")
           @site = @site.gsub("http://", "http://#{credentials}@")
         else
           @site = url
         end

         # This URL may contain special characters, such as accents,
         # which Ruby's URI can’t handle, so let's encode it.
         @site = URI.encode(@site)

         # If a payload has been specified, turn it to json.
         # we should reconsider this in the future in case we need
         # non json payloads in the rest client. We could check the
         # content_typte and act appropriately in the future if it makes
         # sense to do so. Do tests to see if we need to encode this payload
         # like we do with the site URL.
         if @payload.to_s.length > 0
           @payload = @payload.to_json
         end
      end

    end # end of class
  end # end of workers module
end # end of gmq module
