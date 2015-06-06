# Make relative files work
$: << File.expand_path(File.dirname(__FILE__))
# Include our dependencies (workers, db connection, etc)
require 'lib/server_dependencies'

require 'server'
# Run the server
run Resque::Server.new
