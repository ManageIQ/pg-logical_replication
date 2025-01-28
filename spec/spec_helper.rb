require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "pg-logical_replication"

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }
