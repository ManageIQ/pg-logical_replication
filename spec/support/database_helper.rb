require_relative "connection_helper"

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
    # Subscriptions are visible from all databases in the cluster so we need to specify only the subs from the target database.
    conn.async_exec("SELECT subname::TEXT FROM pg_subscription AS sub JOIN pg_database ON sub.subdbid = pg_database.oid WHERE pg_database.datname = current_database()").values.flatten.each do |s|
      conn.async_exec("ALTER subscription #{s} DISABLE")
      conn.async_exec("ALTER subscription #{s} SET (slot_name = NONE)")
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
    # replication_slots are visible from all databases in the cluster so we need to specify only the slots from the source database.
    conn.async_exec("SELECT slot_name::TEXT FROM pg_replication_slots WHERE slot_type = 'logical' AND NOT active AND database = current_database()").values.flatten.each do |slot|
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
