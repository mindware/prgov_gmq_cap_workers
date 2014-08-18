module PRGMQ
  module CAP

    # We have an error middlware - our eye of sauron. It sees all errors:
    # Trap all thrown Exception and fail gracefuly with a
    # 500 and a proper message. This is done when something breaks in the
    # code, and when basically it grabs any unexpected errors. All expected
    # errors are now also caught by this middleware, instead of using
    # grape's "error!" method, we now use raise which is more verbose and
    # can return the current line and more information such as backtrace if
    # our API Config helper has backtrace_errors set to true.
    class ApiErrorHandler < Grape::Middleware::Base
      # Needed for debug method.
      include PRGMQ::CAP::LibraryHelper

      def call!(env)
        @env = env
        begin
          @app.call(@env)
        rescue Exception => e
          # Prepare the JSON error message.

          # if this is one of our AppErrors, grab the custom error message.
          # Store the class name as klass, so that we may call the proper
          # http_code later on.
          # Dev note: If is_a? ever fails, we always can use .ancestors.include?
          if e.is_a? AppError
            message = e.class.data
            klass   = e.class
          elsif e.is_a? Grape::Exceptions::ValidationErrors
            klass   = InvalidParameters
            message = InvalidParameters.data
            message["error"]["app_error"] = "Invalid Parameters: #{e.message}"

          # This next line doesn't contribute to making us completely Store
          # agnostic. We need a specific check for the errors thrown by
          # the drivers used by moneta. We're unable to catch these errors
          # in the Store.rb's self.db method. If you figure it out, this
          # line will not be needed. Until then, let's catch the errors
          # here.
          elsif e.is_a? Redis::BaseError
            klass   = StoreUnavailable
            message = StoreUnavailable.data
          else
            # For all other exceptions, use our generic error
            puts "An #{e.class.to_s.bold.red} error was raised." if Config.debug
            message = AppError.data
            klass = AppError
            message["error"]["app_exception_class"] = "#{e.class.to_s}"
          end
          # Sprinkle some additonal data if we're in development mode.
          if Goliath.env.to_s == "development"
            # # Add additional exception message, which will contain more
            # # information if this is a system exception transformed into
            # # AppError. We'll skip this if it's just a child of AppError,
            # # since it wont contain new information like it does for
            # # other exceptions.
            # if klass == AppError
            #   message["error"]["app_exception_error"]       = e.message
            # end

            # Add the message of the exception to all errors.
            message["error"]["app_exception_message"] = "#{e.message}"
            # If our Config helper is set to print backtrace errors, show them:
            if(Config.backtrace_errors and Config.debug)
              # Provide a full backtrace:
              message["error"]["app_exception_backtrace"] = e.backtrace
            else
              # Provide a full backtrace:
              message["error"]["app_exception_line"] = e.backtrace[0]
            end
          end # end of developer enviornment check

          # Print to STDOUT the full errors if in debug mode.
          error_msg "#{"Error".red}:\n#{message}" if Config.debug
          # Print out dashes to make it easy to destinguish where our
          # request output ends.
          debug "#{ ("-" * 80).bold.yellow }\n"

          # This throw not only ensures we throw the proper Exception,
          # send the proper json error message, but also makes sure to
          # return the proper HTTP code, be it a 500, 400, etc. 
          throw :error, :message => message, :status => klass.http_code
        end # end of begin/rescue
      end # end of call(env)
    end # end of error middlware

    # Base Error, our Internal Server Error.
    class AppError < RuntimeError
      # data is the method used to return hashes with http and app errors.
      def self.data
        # sprinkle some errors and print the Exception name with self.to_s
        {"error" => { "http_error" => "An Internal Server Error ocurred",
                      "http_code" => 500,
                      "app_error" => "An unexpected internal error "+
                                     "has occurred.",
                      "app_code" => 6000
                    }
        }
      end
      # This method is used to retrieve the http error code.
      def self.http_code
          #+ Add logging capability here.
          self.data["error"]["http_code"]
      end

      def self.message
          self.data["error"][""]
      end
    end


    ################################################################
    ########                   Missing                      ########
    ################################################################

    class MissingTransactionId < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: id is required.",
                       "app_code" => 1000
                    }
        }
      end
    end

    class MissingEmail < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: email is required.",
                       "app_code" => 1001
                    }
        }
      end
    end

    class MissingCertificateBase64 < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: certificate_base64 is required.",
                       "app_code" => 1002
                    }
        }
      end
    end

    class MissingSSN < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: ssn is required.",
                       "app_code" => 1003
                    }
        }
      end
    end

    class MissingLicenseNumber < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: license_number is required.",
                       "app_code" => 1004
                    }
        }
      end
    end

    class MissingFirstName < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: first_name is required.",
                       "app_code" => 1005
                    }
        }
      end
    end

    class MissingLastName < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: last_name is required.",
                       "app_code" => 1006
                    }
        }
      end
    end

    class MissingBirthDate < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: birth_date is required.",
                       "app_code" => 1007
                    }
        }
      end
    end

    class MissingResidency < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: residency is required.",
                       "app_code" => 1008
                    }
        }
      end
    end

    class MissingClientIP < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: Client's IP is required.",
                       "app_code" => 1009
                    }
        }
      end
    end

    class MissingStatus < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: status is required.",
                       "app_code" => 1010
                    }
        }
      end
    end

    class MissingReason < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: reason is required.",
                       "app_code" => 1011
                    }
        }
      end
    end


    class MissingAnalystApprovalDate < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: analyst_approval_datetime is"+
                                      " required.",
                       "app_code" => 1012
                    }
        }
      end
    end
    class MissingAnalystTransactionId < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: analyst_transaction_id is"+
                                      " required.",
                       "app_code" => 1013
                    }
        }
      end
    end

    class MissingAnalystInternalStatusId < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: analyst_internal_status_id "+
                                      "is required.",
                       "app_code" => 1014
                    }
        }
      end
    end

    class MissingAnalystDecisionCode < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: decision_code "+
                                      "is required.",
                       "app_code" => 1015
                    }
        }
      end
    end

    class MissingAnalystId < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: analyst_id "+
                                      "is required.",
                       "app_code" => 1016
                    }
        }
      end
    end

    class MissingAnalystFullname < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: analyst_fullname "+
                                      "is required.",
                       "app_code" => 1017
                    }
        }
      end
    end

    class MissingLanguage < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Parameter: language "+
                                      "is required.",
                       "app_code" => 1018
                    }
        }
      end
    end


    ################################################################
    ########                   Invalid                      ########
    ################################################################

    class InvalidTransactionId < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid transaction id provided.",
                       "app_code" => 2000
                    }
        }
      end
    end

    class InvalidEmail < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid email provided.",
                       "app_code" => 2001
                    }
        }
      end
    end

    class InvalidStatus < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid transaction status. A valid "+
                       "transaction status is one of the following: completed,"+
                       " pending, retry, processing, failed.",
                       "app_code" => 2002
                    }
        }
      end
    end

    class InvalidSSN < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid ssn provided.",
                       "app_code" => 2002
                    }
        }
      end
    end

    class InvalidSSN < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid ssn provided.",
                       "app_code" => 2003
                    }
        }
      end
    end

    class InvalidLicenseNumber < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid license_number provided.",
                       "app_code" => 2004
                    }
        }
      end
    end

    class InvalidFirstName < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid name provided.",
                       "app_code" => 2005
                    }
        }
      end
    end


    class InvalidBirthDate < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid birth_date provided.",
                       "app_code" => 2006
                    }
        }
      end
    end

    class InvalidResidency < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid residency provided.",
                       "app_code" => 2007
                    }
        }
      end
    end

    class InvalidClientIP < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid Client IP provided.",
                       "app_code" => 2008
                    }
        }
      end
    end

    class InvalidReason < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid reason provided.",
                       "app_code" => 2009
                    }
        }
      end
    end

    class InvalidCertificateBase64 < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid certificate_base64 provided.",
                       "app_code" => 2010
                    }
        }
      end
    end

    class InvalidMiddleName < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid middle name provided.",
                       "app_code" => 2011
                    }
        }
      end
    end

    class InvalidLastName < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid last name provided.",
                       "app_code" => 2012
                    }
        }
      end
    end

    class InvalidMotherLastName < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid mother last name provided.",
                       "app_code" => 2013
                    }
        }
      end
    end

    class NotOldEnough < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Cannot issue a certificate for minors.",
                       "app_code" => 2014
                    }
        }
      end
    end

    class InvalidAnalystApprovalDate < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid analyst_approval_date. You must"+
                                      " supply a valid utc timestamp (example:"+
                                      " 2014-05-29 13:23:39 UTC).",
                       "app_code" => 2015
                    }
        }
      end
    end

    class InvalidAnalystDecisionCode < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid decision_code provided.",
                       "app_code" => 2016
                    }
        }
      end
    end

    class InvalidAnalystId < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid analyst_id provided.",
                       "app_code" => 2017
                    }
        }
      end
    end

    class InvalidAnalystFullname < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid analyst_fullname provided.",
                       "app_code" => 2018
                    }
        }
      end
    end

    class InvalidLanguage < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid language provided.",
                       "app_code" => 2019
                    }
        }
      end
    end

    ################################################################
    ########          Additional Validation Errors          ########
    ################################################################


    class InvalidCredentials < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "401 Unauthorized",
                       "http_code" => 401,
                       "app_error" => "Unauthorized: Username or "+
                                     "password is incorrect.",
                       "app_code" => 4000
                    }
        }
      end
    end

    class InvalidAccess < PRGMQ::CAP::AppError
      def self.data
        { "error" => {  "http_error" => "403 Forbidden",
                        "http_code" => 403 ,
                        "app_error" => "Forbidden: Your credentials do"+
                        " not allow you access to that resource.",
                        "app_code" => 4500
                    }
        }
      end
    end

    class InvalidParameters < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_error" => "400 Bad Request",
                       "http_code" => 400,
                       "app_error" => "Invalid Parameters",
                       "app_code" => 2999
                    }
        }
      end
    end


    ################################################################
    ########                 Not Found                      ########
    ################################################################

    class ResourceNotFound < PRGMQ::CAP::AppError
      def self.data
        { "error" => {  "http_error" => "404 Not Found",
                        "http_code" => 404,
                        "app_error" => "The resource"+
                        " provided in the URL doesn't exist. Check the API "+
                        "documentation and version for valid URL resources "+
                        "and their corresponding HTTP verbs (ie: GET, PUT, "+
                        "POST, DELETE).",
                        "app_code" => 5000
                    }
        }
      end
    end

    class ItemNotFound < PRGMQ::CAP::AppError
      def self.data
        { "error" => {  "http_error" => "404 Not Found",
                        "http_code" => 404,
                        "app_error" => "The requested item could not be found."+
                        " The item might've expired, been deleted or may have "+
                        "never existed.",
                        "app_code" => 5001
                    }
        }
      end
    end


    ################################################################
    ########               Internal Errors                  ########
    ################################################################

    class InvalidAccessGroup < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_message" => "500 Internal Server Error",
                       "http_code" => 500,
                       "app_error"  => "Internal Server Error: The user has an "+
                       "improperly configured access group. "+
                       "The administrator needs to set a proper array as a "+
                       "data structure for the access group.",
                       "app_code" => 6001
                    }
        }
      end
    end

    class MissingConfigFile < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_message" => "500 Internal Server Error",
                       "http_code" => 500,
                       "app_error"  => "The configuration file is missing or "+
                                       "access to it is unavailable",
                       "app_code" => 6002
                    }
        }
      end
    end

    class InvalidConfigFile < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_message" => "500 Internal Server Error",
                       "http_code" => 500,
                       "app_error"  => "The API's configuration file is "+
                                       "invalid and could not be parsed.",
                       "app_code" => 6003
                    }
        }
      end
    end

    class MissingAccessGroup < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_message" => "500 Internal Server Error",
                       "http_code" => 500,
                       "app_error"  => "The user's config is missing "+
                                       "a security group.",
                       "app_code" => 6004
                    }
        }
      end
    end

    class InvalidPasskeyLength < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_message" => "500 Internal Server Error",
                       "http_code" => 500,
                       "app_error"  => "The system configured passkey for "+
                                    "the user is of an invalid length.",
                       "app_code" => 6005
                    }
        }
      end
    end

    class InvalidNonJsonRecord < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_message" => "500 Internal Server Error",
                       "http_code" => 500,
                       "app_error"  => "The record found "+
                       "was in an improper format and could not be "+
                       "properly parsed.",
                       "app_code" => 6006
                    }
        }
      end
    end

    class InvalidErrorProvided < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_message" => "500 Internal Server Error",
                       "http_code" => 500,
                       "app_error"  => "An invalid error was raised. This is "+
                       "a programming error. Someone raised an error but did "+
                       "not properly define it for the API, as children of "+
                       "the AppError class.",
                       "app_code" => 6106
                    }
        }
      end
    end


    ################################################################
    ########          External Systems  Unavailable         ########
    ################################################################


    class GMQUnavailable < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_message" => "502 Internal Server Error",
                       "http_code" => 502,
                       "app_error"  => "The Government Message "+
                                       "Queue could not be accessed.",
                       "app_code" => 7000
                    }
        }
      end
    end

    class StoreUnavailable < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_message" => "502 Internal Server Error",
                       "http_code" => 502,
                       "app_error"  => "The Transaction Store could not be "+
                                       "accessed.",
                       "app_code" => 7001
                    }
        }
      end
    end

    ################################################################
    ########            Down for Maintenance                ########
    ################################################################

    class ServiceUnavailable < PRGMQ::CAP::AppError
      def self.data
        { "error" => { "http_message" => "503 Service Unavailable",
                       "http_code" => 503,
                       "app_error"  => "This service is currently "+
                                       "unavailable. Down for maintenance.",
                       "app_code" => 8000
                    }
        }
      end
    end

  end
end
