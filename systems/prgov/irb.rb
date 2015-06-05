require '../lib/rest'
require 'resque'
require 'resque-scheduler'
require 'resque-retry'
require 'dotenv'

require 'csv'

# Load our environment variables from the hidden '.env' file in this projects root folder.
Dotenv.load

require 'app/helpers/config'
require 'app/helpers/store'

# Setup the configuration
GMQ::Workers::Config.check

# Resque accepts an existing redis connection, so let's
# make it use ours.
# TODO: update this later so that resque gains db reconnection capabilities
Resque.redis = GMQ::Workers::Store.db

# This is the recommended way to configure Resque but
# it errors out. So we use what's above.
# Resque.configure do |configuration|
#   configuration.redis = GMQ::Workers::Store.db
# end

# require our jobs & application code.
# We'll require all existing workers in the core/workers directory
# These are used both by the Resque workers as well as the Resque-web
Dir["app/core/workers/*.rb"].each {|file| require file }
