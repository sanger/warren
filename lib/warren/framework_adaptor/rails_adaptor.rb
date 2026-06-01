# frozen_string_literal: true

require 'active_record'

module Warren
  # Namespace for framework adaptors.
  #
  # A FrameworkAdaptor should implement the following instance methods:
  #
  # == recovered? => Bool
  # Indicates that any temporary issues (such as database connectivity problems)
  # are resolved and consumers may restart.
  #
  # == handle
  #
  # Wraps the processing of each message, is expected to `yield` to allow
  # processing. May be responsible for handling connection pools, and
  # framework-specific exceptions. Raising {Warren::Exceptions::TemporaryIssue}
  # here will cause consumers to sleep until `recovered?` returns true.
  #
  # == env => String
  #
  # Returns the current environment of the application.
  #
  # == logger => Logger
  #
  # Returns your application logger. Is expected to be compatible with the
  # standard library Logger class.
  # @see https://ruby-doc.org/stdlib-2.7.0/libdoc/logger/rdoc/Logger.html
  #
  # == load_application
  #
  # Called upon running `warren consumer start`. Should ensure your application
  # is correctly loaded sufficiently for processing messages
  #
  module FrameworkAdaptor
    # The RailsAdaptor provides error handling and application
    # loading for Rails applications
    class RailsAdaptor
      # Matches exceptions that represent a lost or unavailable database
      # connection, so they can be treated as temporary issues (pause + requeue)
      # rather than permanent message failures (dead-letter).
      #
      # We override `===` so this can be used directly in a `rescue` clause.
      # When an exception is raised, Ruby evaluates `ConnectionMissing === e`;
      # returning true here causes the rescue block to be entered.
      #
      # ActiveRecord wraps all adapter-level connection errors in its own
      # exception hierarchy, so checking these classes is both reliable and
      # adapter-agnostic. Add to CONNECTION_ERRORS if new connectivity
      # exception types need to be treated as temporary issues.
      class ConnectionMissing
        CONNECTION_ERRORS = [
          ActiveRecord::ConnectionNotEstablished,
          ActiveRecord::ConnectionFailed,
          ActiveRecord::AdapterTimeout
        ].freeze

        def self.===(exception)
          CONNECTION_ERRORS.any? { |klass| exception.is_a?(klass) }
        end
      end

      #
      # Checks that the database has recovered to allow message processing
      #
      # @return [Bool] Returns true if the application has recovered
      #
      def recovered?
        ActiveRecord::Base.connection.reconnect!
        true
      rescue StandardError
        false
      end

      #
      # Checks ensures a database connection has been checked out before
      # yielding to allow message processing. Rescues loss of the database
      # connection and raises {Warren::Exceptions::TemporaryIssue} to send
      # the consumers to sleep until it recovers.
      #
      # @return [Void]
      #
      def handle
        with_connection do
          yield
        rescue ConnectionMissing => e
          raise Warren::Exceptions::TemporaryIssue, e.message
        end
      end

      def with_connection
        begin
          ActiveRecord::Base.connection
        rescue StandardError => e
          raise Warren::Exceptions::TemporaryIssue, e.message
        end

        yield
      ensure
        # Although Rails 7.2 recommends using `ActiveRecord::Base.connection_handler.clear_active_connections!`
        # to clear all active connections (especially in applications with multiple databases),
        # Y25-234 investigated the performance and applicability of this versus
        # `ActiveRecord::Base.connection_pool.release_connection`.
        #
        # Since Unified Warehouse (the primary Warren consumer) does not use multiple databases,
        # `release_connection` was found to be more targeted and performant.
        # Using `clear_active_connections!` would be redundant and potentially less efficient in this context.
        ActiveRecord::Base.connection_pool.release_connection
      end

      # Returns the rails environment
      #
      # @return [ActiveSupport::StringInquirer] The rails environment
      def env
        Rails.env
      end

      # Returns the configured logger
      #
      # @return [Logger,ActiveSupport::Logger,...] The application logger
      def logger
        Rails.logger
      end

      # Triggers full loading of the rails application and dependencies
      #
      # @return [Void]
      def load_application
        $stdout.puts 'Loading application...'
        require './config/environment'
        Warren.load_configuration
        $stdout.puts 'Loaded!'
      rescue LoadError
        # Need to work out an elegant way to handle non-rails
        # apps
        $stdout.puts 'Could not auto-load application'
      end
    end
  end
end
