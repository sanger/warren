# frozen_string_literal: true

require 'logger'

module Warren
  module Subscriber
    # A message takes a rabbitMQ message, and handles its acknowledgement
    # or rejection.
    class RailsBase < Base
      # An artificial exception class to specifically rescue various database connection
      # errors.
      class ConnectionMissing
        # Database connection messages indicated temporary issues connecting to the database
        # We handle them separately to ensure we can recover from network issues.
        DATABASE_CONNECTION_MESSAGES = [
          /Mysql2::Error: closed MySQL connection:/, # 2013,
          /Mysql2::Error: MySQL server has gone away/, # 2006
          /Mysql2::Error: Can't connect to local MySQL server through socket/, # , 2002, 2001, 2003, 2004, 2005
          /Mysql2::Error::ConnectionError: Lost connection to MySQL server during query/, # 2013
          /Mysql2::Error: MySQL client is not connected/
        ].freeze

        def self.===(other)
          return false unless defined?(ActiveRecord::StatementInvalid)

          other.is_a?(ActiveRecord::StatementInvalid) && database_connection_error?(other)
        end

        def self.database_connection_error?(exception)
          DATABASE_CONNECTION_MESSAGES.any? { |regex| regex.match?(exception.message) }
        end
      end

      def handle_exceptions
        yield
      rescue ConnectionMissing => e
        raise Warren::Exceptions::TemporaryIssue, e.message
      end
    end
  end
end
