require "pg"

module PG
  module LogicalReplication
    class CommandBuilder
      attr_accessor :connection

      def initialize(connection)
        @connection = connection
      end

      def command_with_options(sql, keyword, options)
        raise CommandBuilderError, "Unrecognized keyword #{keyword}" unless ["WITH", "SET"].include?(keyword)
        if options.empty?
          case keyword
          when "WITH"
            return sql
          when "SET"
            raise CommandBuilderError, "Keyword SET requires options"
          end
        end
        "#{sql} #{keyword} (#{parameters_list(options)})"
      end

      private

      def parameters_list(options)
        options.to_a.map do |k, v|
          "#{connection.quote_ident(k)} = #{safe_value(k, v)}"
        end.join(", ")
      end

      VALUE_TYPES_BY_KEY = {
        # subscription options
        "connect"            => "bool",
        "copy_data"          => "bool",
        "create_slot"        => "bool",
        "enabled"            => "bool",
        "refresh"            => "bool",
        "slot_name"          => "string",
        "synchronous_commit" => "string",
        # publication options
        "publish"            => "string"
      }.freeze

      def safe_value(key, value)
        case VALUE_TYPES_BY_KEY[key]
        when "string"
          value == "NONE" ? "NONE" : quote_string(value)
        when "bool"
          value ? "true" : "false"
        else
          raise PG::LogicalReplication::CommandBuilderError, "Option type for key '#{key}' not defined"
        end
      end

      def quote_string(s)
        "#{connection.escape_literal(s)}"
      end
    end
  end
end
