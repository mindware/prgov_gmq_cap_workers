# This file is meant to overwrite core features that are expected
# by the app/helpers and app/models. As those pieces of code are
# at this time copied directly from the API, and the API's version is
# the authoritative version, we do not modify them directly, but hack them
# through this definitions file.
# Require the ruby standard logger
require 'logger'
# Our hack for the helper's expectation of a Webserver's environment.
class Goliath
  def self.env
    "production"
  end
end
# Our hack for the helpers expectation of the API logger.
class API
  def self.logger
    Logger
  end
end

# Hack to define the PRGMQ::CAP::Grape used by helpers/errors.rb 
module PRGMQ 
	module CAP
		module Grape
			module Middleware
				class Base
				end
			end
		end
	end
end
