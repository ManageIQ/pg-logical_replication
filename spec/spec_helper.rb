require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "pg-logical_replication"

module ConnectionHelper
  def self.source_database_connection
    @source_database_connection ||= PG::Connection.new(:dbname => "logical_test").tap do |c|
      c.set_notice_receiver { |r| nil }
    end
  end

  def self.target_database_connection
    @target_database_connection ||= PG::Connection.new(:dbname => "logical_test_target").tap do |c|
      c.set_notice_receiver { |r| nil }
    end
  end

  def self.with_each_connection
    [source_database_connection, target_database_connection].each do |conn|
      yield conn
    end
  end
end

module DatabaseHelper
  def self.tables
    %w(table1 table2 table3 table4)
  end

  def self.create_tables
    ConnectionHelper.with_each_connection do |conn|
      tables.each do |t|
        conn.async_exec(<<-SQL)
          CREATE TABLE IF NOT EXISTS #{t} (
            id   SERIAL PRIMARY KEY,
            data VARCHAR(50)
          )
        SQL
      end
    end
  end

  def self.drop_tables
    ConnectionHelper.with_each_connection do |conn|
      tables.each { |t| conn.async_exec("DROP TABLE IF EXISTS #{t}") }
    end
  end

  def self.drop_subscriptions
    conn = ConnectionHelper.target_database_connection
    conn.async_exec("SELECT subname::TEXT from pg_subscription").values.flatten.each do |s|
      conn.async_exec("DROP SUBSCRIPTION #{s}")
    end
  end

  def self.drop_publications
    conn = ConnectionHelper.source_database_connection
    conn.async_exec("SELECT pubname::TEXT from pg_publication").values.flatten.each do |p|
      conn.async_exec("DROP PUBLICATION #{p}")
    end
  end

  def self.drop_replication_slots
    conn = ConnectionHelper.source_database_connection
    conn.async_exec("SELECT slot_name::TEXT FROM pg_replication_slots WHERE slot_type = 'logical' AND NOT active").values.flatten.each do |slot|
      conn.async_exec("SELECT pg_drop_replication_slot('#{slot}')")
    end
  end

  def self.with_clean_environment
    yield
  ensure
    drop_subscriptions
    drop_publications
    drop_replication_slots
  end
end
