require "pg"

module PG
  module LogicalReplication
    class Client
      attr_reader :connection
      attr_reader :command_builder

      # @param connection [PG::Connection] Database Connection
      def initialize(connection)
        @connection      = connection
        @command_builder = PG::LogicalReplication::CommandBuilder.new(connection)
      end

      # Reports on replication lag from publisher to subscriber nodes
      # This method must be run on the publisher node
      #
      # @return [Array<Hash<String,String>>] List of returned lag and application names,
      #   one for each replication process
      def lag_bytes
        typed_exec(<<-SQL).to_a
          SELECT
            pg_wal_lsn_diff(pg_current_wal_insert_lsn(), flush_lsn) AS lag_bytes,
            application_name
          FROM
            pg_stat_replication
        SQL
      end

      # Reports on replication bytes of WAL being retained for each replication slot
      # This method must be run on the publisher node
      #
      # @return [Array<Hash<String,String>>] List of returned WAL bytes and replication slot names,
      #   one for each replication process
      def wal_retained_bytes
        typed_exec(<<-SQL).to_a
          SELECT
            pg_wal_lsn_diff(pg_current_wal_insert_lsn(), restart_lsn) AS retained_bytes,
            slot_name::TEXT
          FROM
            pg_replication_slots
          WHERE
            plugin = 'pgoutput'
        SQL
      end

      # Creates a subscription to a publisher node
      #
      # @param name [String] subscription name
      # @param conninfo_hash [Hash] publisher node connection info
      # @param publications [Array<String>] publication names to subscribe to
      # @param options [Hash] optional parameters for CREATE SUBSCRIPTION
      def create_subscription(name, conninfo_hash, publications, options = {})
        connection_string = connection.escape_string(PG::Connection.parse_connect_args(conninfo_hash))
        base_command = <<-SQL
          CREATE SUBSCRIPTION #{connection.quote_ident(name)}
                 CONNECTION '#{connection_string}'
                 PUBLICATION #{safe_list(publications)}
        SQL
        typed_exec(command_builder.command_with_options(base_command, "WITH", options))
      end

      # Disconnects the subscription and removes it
      #
      # @param name [String] subscription name
      # @param ifexists [Boolean] if true an error is not thrown when the subscription does not exist
      def drop_subscription(name, ifexists = false)
        typed_exec("DROP SUBSCRIPTION#{" IF EXISTS" if ifexists} #{connection.quote_ident(name)}")
      end

      # Updates a subscription connection string
      #
      # @param name [String] subscription name
      # @param conninfo_hash [Hash] new external connection hash to the publisher node
      def set_subscription_conninfo(name, conninfo_hash)
        connection_string = connection.escape_string(PG::Connection.parse_connect_args(conninfo_hash))
        typed_exec("ALTER SUBSCRIPTION #{connection.quote_ident(name)} CONNECTION '#{connection_string}'")
      end

      # Changes list of subscribed publications
      #
      # @param name [String] subscription name
      # @param publications [Array<String>] publication names to subscribe to
      # @param options [Hash] optional parameters
      def set_subscription_publications(name, publications, options = {})
        base_command = <<-SQL
          ALTER SUBSCRIPTION #{connection.quote_ident(name)}
          SET PUBLICATION #{safe_list(publications)}
        SQL
        typed_exec(@command_builder.command_with_options(base_command, "WITH", options))
      end

      # Fetch missing table information from publisher
      #
      # @param name [String] subscription name
      # @param options [Hash] optional parameters
      def sync_subscription(name, options = {})
        base_command = <<-SQL
          ALTER SUBSCRIPTION #{connection.quote_ident(name)} REFRESH PUBLICATION
        SQL
        typed_exec(@command_builder.command_with_options(base_command, "WITH", options))
      end

      # Enables the previously disabled subscription
      #
      # @param name [String] subscription name
      def enable_subscription(name)
        typed_exec("ALTER SUBSCRIPTION #{connection.quote_ident(name)} ENABLE")
      end

      # Disables the running subscription
      #
      # @param name [String] subscription name
      def disable_subscription(name)
        typed_exec("ALTER SUBSCRIPTION #{connection.quote_ident(name)} DISABLE")
      end

      # Alters parameters originally set by CREATE SUBSCRIPTION
      #
      # @param name [String] subscription name
      # @param options [Hash] parameters to set
      def alter_subscription_options(name, options)
        base_command = "ALTER SUBSCRIPTION #{connection.quote_ident(name)}"
        typed_exec(command_builder.command_with_options(base_command, "SET", options))
      end

      # Sets the owner of the subscription
      #
      # @param name [String] subscription name
      # @param owner [String] new owner user name
      def set_subscription_owner(name, owner)
        typed_exec("ALTER SUBSCRIPTION #{connection.quote_ident(name)} OWNER TO #{connection.quote_ident(owner)}")
      end

      # Renames the subscription
      #
      # @param name [String] current subscription name
      # @param new_name [String] new subscription name
      def rename_subscription(name, new_name)
        typed_exec("ALTER SUBSCRIPTION #{connection.quote_ident(name)} RENAME TO #{connection.quote_ident(new_name)}")
      end

      # Shows status and basic information about all subscriptions
      #
      # @return [Hash] a hash with the subscription information
      #   keys:
      #     subscription_name
      #     owner
      #     enabled
      #     subscription_dsn
      #     slot_name
      #     publications
      #     remote_replication_lsn
      #     local_replication_lsn
      def subscriptions
        typed_exec(<<-SQL).to_a
          SELECT
            sub.subname::TEXT     AS subscription_name,
            pg_user.usename::TEXT AS owner,
            sub.subenabled        AS enabled,
            sub.subconninfo       AS subscription_dsn,
            sub.subslotname::TEXT AS slot_name,
            sub.subpublications   AS publications,
            stat.remote_lsn::TEXT AS remote_replication_lsn,
            stat.local_lsn::TEXT  AS local_replication_lsn
          FROM 
            pg_subscription AS sub
            JOIN pg_user
              ON sub.subowner = usesysid
            LEFT JOIN pg_replication_origin_status stat
              ON concat('pg_', sub.oid) = stat.external_id
        SQL
      end

      # Lists the current publications
      #
      # @return [Array<String>] publication names
      def publications
        typed_exec(<<-SQL)
          SELECT
            pubname::TEXT AS name,
            usename::TEXT AS owner,
            puballtables,
            pubinsert,
            pubupdate,
            pubdelete
          FROM
            pg_publication
            JOIN pg_user ON pubowner = usesysid
        SQL
      end

      # Creates a new publication
      #
      # @param name [String] publication name
      # @param all_tables [Boolean] replicate changes for all tables, including ones created in the future
      # @param tables [Array<String>] tables to be added to the publication, ignored if all_tables is true
      # @param options [Hash] optional parameters
      def create_publication(name, all_tables = false, tables = [], options = {})
        base_command = "CREATE PUBLICATION #{connection.quote_ident(name)}"
        if all_tables
          base_command << " FOR ALL TABLES"
        elsif !tables.empty?
          base_command << " FOR TABLE #{safe_list(tables)}"
        end
        typed_exec(@command_builder.command_with_options(base_command, "WITH", options))
      end

      # Adds tables to a publication
      #
      # @param name [String] publication name
      # @param tables [Array<String>] table names to add
      def add_tables_to_publication(name, tables)
        typed_exec("ALTER PUBLICATION #{connection.quote_ident(name)} ADD TABLE #{safe_list(tables)}")
      end

      # Sets the tables included in a publication
      #
      # @param name [String] publication name
      # @param tables [Array<String>] table names
      def set_publication_tables(name, tables)
        typed_exec("ALTER PUBLICATION #{connection.quote_ident(name)} SET TABLE #{safe_list(tables)}")
      end

      # Removes tables from a publication
      #
      # @param name [String] publication name
      # @param tables [Array<String>] table names to remove
      def remove_tables_from_publication(name, tables)
        typed_exec("ALTER PUBLICATION #{connection.quote_ident(name)} DROP TABLE #{safe_list(tables)}")
      end

      # Alters parameters originally set by CREATE PUBLICATION
      #
      # @param name [String] publication name
      # @param options [Hash] parameters to set
      def alter_publication_options(name, options)
        base_command = "ALTER PUBLICATION #{connection.quote_ident(name)}"
        typed_exec(command_builder.command_with_options(base_command, "SET", options))
      end

      # Sets the owner of a publication
      #
      # @param name [String] publication name
      # @param owner [String] new owner user name
      def set_publication_owner(name, owner)
        typed_exec("ALTER PUBLICATION #{connection.quote_ident(name)} OWNER TO #{connection.quote_ident(owner)}")
      end

      # Renames a publication
      #
      # @param name [String] current publication name
      # @param new_name [String] new publication name
      def rename_publication(name, new_name)
        typed_exec("ALTER PUBLICATION #{connection.quote_ident(name)} RENAME TO #{connection.quote_ident(new_name)}")
      end

      # Remove a publication
      #
      # @param name [String] publication name
      # @param ifexists [Boolean] if true an error is not thrown when the publication does not exist
      def drop_publication(name, ifexists = false)
        typed_exec("DROP PUBLICATION#{" IF EXISTS" if ifexists} #{connection.quote_ident(name)}")
      end

      # Lists the tables currently in the publication
      #
      # @param set_name [String] publication name
      # @return [Array<String>] table names
      def tables_in_publication(name)
        typed_exec(<<-SQL, name).values.flatten
          SELECT tablename::TEXT
          FROM pg_publication_tables
          WHERE pubname = $1
        SQL
      end

      private

      def safe_list(list)
        list.map { |e| connection.quote_ident(e) }.join(", ")
      end

      def typed_exec(sql, *params)
        result = connection.async_exec(sql, params, nil, PG::BasicTypeMapForQueries.new(connection))
        result.map_types!(PG::BasicTypeMapForResults.new(connection))
      end
    end
  end
end
