require "pg/logical_replication/version"
require "pg/logical_replication/client"
require "pg/logical_replication/command_builder"

module PG
  module LogicalReplication
    class Error < StandardError; end
    class CommandBuilderError < PG::LogicalReplication::Error; end
  end
end
