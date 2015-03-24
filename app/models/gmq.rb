# A class that represents the Government Message Queue.
# This class allows for quick access to the distributed
# computing architecture, in order to enqueue jobs.
class GMQ

  def health_check
    puts request("/health")
  end

  def self.enqueue_email(payload)
    # This method speaks with the CAP API to enqueue an email
    # If we enqueued successfully:
      # return true
    # else
    # false
    # puts request("")
    # test
    # get('/transaction')
    if post('/mail', payload)
      return true
    else
      return false
    end
  end

  # Perform an HTTP Get against the GMQ
  def self.get(uri, payload=nil)
    self.request(uri, method='get', payload)
  end
  # Perform an HTTP POST against the GMQ
  def self.post(uri, payload=nil)
    self.request(uri, method='post', payload)
  end
  # Perform an HTTP DELETE against the GMQ
  def self.delete(uri, payload=nil)
    self.request(uri, method='delete', payload)
  end
  # Perform an HTTP PUT against the GMQ
  def self.put(uri, payload=nil)
    self.request(uri, method='put', payload)
  end

  # Performs the actual HTTP Requests
  # against the GMQ
  def self.request(uri, method='get', payload=nil)
    site = "#{gmq_url}#{uri}"
    content_type = nil
    begin
      # If have a payload to deliver
      if(payload)
        # set the proper content type
        content_type = :json
        response = RestClient.send method, site, payload.to_json,
                                   :content_type => :json,
                                   :accept => :json
      # This is a non-payload request
      else
        response = RestClient.send method, site
      end
      # check response header for errors
      # if response error inside:
      # return false
      # if response no errors inside:
      puts "Performing request to #{self}"
      puts "HTTP Code:\n#{response.code}\n"
      puts "Headers:\n#{response.headers}\n"
      puts "Result:\n#{response.gsub(",", ",\n").to_str}\n"
      puts "End of request."

      result = JSON.parse(response)
      return result
    rescue Errno::ECONNREFUSED => e
      # connection error - server offline or network failure
      puts "We got a connection refused, everybody."
      puts e.inspect.to_s
      raise GMQ_ERROR, e
    rescue RestClient::Unauthorized => e
      # 401
      puts "Bad username or password. Cannot login to the GMQ"
      puts e.inspect.to_s
      raise GMQ_ERROR, e
    rescue RestClient::BadRequest => e
      # 400
      puts "Bad Request"
      puts e.inspect.to_s
      raise GMQ_ERROR, e
    rescue RestClient::Forbidden => e
      # 403
      puts "User has no authorization to access that resource."
      raise GMQ_ERROR, e
    rescue RestClient::ResourceNotFound => e
      # 404
      puts "404"
      raise GMQ_ERROR, e
    rescue RestClient::InternalServerError => e
      # 500
      puts "500"
      raise GMQ_ERROR, e
    rescue RestClient::ServiceUnavailable => e
      # 503 Service unavailable - maintenance
      puts "We're in maintenance mode."
      puts e.inspect.to_s
      raise GMQ_ERROR, e
    rescue Exception => e
      # When unexpected errors ocurr:
      puts "Error class is #{e.class}"
      puts e.inspect.to_s
      error = e.message.strip
      # if the error isn't empty
      if(error.to_s.length > 0)
        # if its likely this is a JSON
        # RestClient returns errors in the following form:
        # 400 Bad Request: {"error":... }
        # In the documentation it says it does so in this manner:
        # 400 Bad Request | {"error":... }
        # In order to be tolerant to future changes, we're
        # simply going to drop everything that comes before
        # the actual json.
        if(error[0] == "{" or error[0] == "[")
          error = JSON.parse(error)

          # Proceed to check the error type:
          if(error.has_key? "error")
            puts error["error"]
          end
        end
      end
      return false
    end
  end

  def self.enqueue_cap_transaction(payload)
    # This method speaks with the CAP API of the GMQ to generate a transaction
    # If we enqueued successfully:
      # true
    # else
    # false
    request("/transaction", 'post', payload)
  end

  def self.test
      payload = {
      		:first_name => "Andrés",
      		:last_name  => "Colón",
      		:mother_last_name => "Pérez",
      		:ssn	=> "123561234",
      		:license_number => "123456789",
      		:birth_date => "***REMOVED***2",
      		:residency  => "San Juan",
      		:IP   	    => "192.168.1.1",
      		:reason	    => "good enough",
      		:birth_place=> "San Juan",
      		:email	    => "andres@thoughtware.tv",
      		:language   => "spanish"
  	 }
     self.enqueue_cap_transaction(payload)
  end

  private
  def self.basic_authentication
    "#{ENV["GMQ_CAP_USER"]}:#{ENV["GMQ_CAP_PASSWORD"]}"
  end

  # Returns the proper URL to access a gmq resource:
  # http(s)://user:password@host:port
  def self.gmq_url(https=false)
    "http#{(https ? "s" : "")}://#{basic_authentication}@"+
    "#{ENV["GMQ_CAP_HOST"]}:#{ENV["GMQ_CAP_PORT"]}#{ENV["GMQ_CAP_API"]}"
  end

end


################################################################
########                   Errors                       ########
################################################################

class GMQ_ERROR < RuntimeError
end
