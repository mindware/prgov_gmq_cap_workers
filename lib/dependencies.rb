# This dependency file is used both by the server (resque-web) and the
# workers (resque workers). Here are the dependencies each have in common.
# They're all in the same file so that we don't have to remember to change
# both of their files each time something changes. This file is inherited
# by both server_dependencies (resque-web) and worker_dependencies (resque).
# Only keep here what both of them need and have in common, otherwise use
# their respective dependencies configuration files.
require 'resque'
require 'resque-scheduler'
require 'resque-retry'
require 'dotenv'
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

# Set the logger
# Resque supports any Logger that is a duck type of the Ruby standard library's built-in Logger class. By default Resque will log to STDOUT. We can configure it to use our logger
# More options: https://github.com/resque/resque/wiki/Logging
#Resque.logger = GMQ::Workers::Config.logger
#Resque.logger = Logger.new
Resque.logger.level = Logger::DEBUG
# During production, you may want to set it to:
#Resque.logger.level = Logger::INFO
