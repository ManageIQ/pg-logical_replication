require "bundler/gem_tasks"
require "rspec/core/rake_task"

require_relative "spec/support/connection_helper"

def create_database(dbname)
  c = ConnectionHelper.connection_for("postgres")
  c.async_exec("CREATE DATABASE #{dbname}")
rescue PG::DuplicateDatabase => err
  raise unless err.message =~ /already exists/
end

def drop_database(dbname)
  c = ConnectionHelper.connection_for("postgres")
  c.async_exec("DROP DATABASE #{dbname}")
rescue PG::InvalidCatalogName => err
  raise unless err.message =~ /does not exist/
end

namespace :spec do
  desc "Setup the test databases"
  task :setup => :teardown do
    create_database("logical_test")
    create_database("logical_test_target")
  end

  desc "Teardown the test databases"
  task :teardown do
    drop_database("logical_test")
    drop_database("logical_test_target")
  end
end

RSpec::Core::RakeTask.new(:spec)
task :default => :spec
