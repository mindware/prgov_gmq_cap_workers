#!/usr/bin/env ruby
# First, fix the paths so that everything under this directory
# is in the ruby path. This way we don't have to include relative filepaths
$: << File.expand_path(File.dirname(__FILE__) +"/../../")

# We're using bundler to include our gems
require 'bundler/setup'
# Load our Gemfile
Bundler.require
# Load environment variables
Dotenv.load
require "app/helpers/library"
# Dir["app/helpers/*.rb"].each {|file| require file }
# Spice up the String class with color capabilities.
require 'app/models/certificate'

cert = GMQ::Workers::Certificate.new("../../files/base64/cert.base624", "file")
cert.dump("../../files/pdf/cert3.pdf")
