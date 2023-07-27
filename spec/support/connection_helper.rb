module ConnectionHelper
  def self.connection_for(dbname)
    require "pg"
    PG::Connection.new("postgresql://#{ENV["POSTGRESQL_USER"]}:#{ENV["POSTGRESQL_PASSWORD"]}@#{ENV["POSTGRESQL_HOST"]}:5432/#{dbname}?sslmode=disable")
  end

  def self.source_database_connection
    @source_database_connection ||= connection_for("logical_test").tap do |c|
      c.set_notice_receiver { |r| nil }
    end
  end

  def self.target_database_connection
    @target_database_connection ||= connection_for("logical_test_target").tap do |c|
      c.set_notice_receiver { |r| nil }
    end
  end

  def self.with_each_connection
    [source_database_connection, target_database_connection].each do |conn|
      yield conn
    end
  end
end
