# frozen_string_literal: true

module Warren
  # Namespace for framework adaptors.
  # A FrameworkAdaptor should implement the following instance methods:
  #
  ## recovered? => Bool
  # Indicates that any temporary issues (such as database connectivity problems)
  # are resolved and consumers may restart.
  #
  ## handle
  #
  # Wraps the processing of each message, is expected to `yield` to allow
  # processing. May be responsible for handling connection pools, and
  # framework-specific exceptions. Raising {Warren::Exceptions::TemporaryIssue}
  # here will cause consumers to sleep until `recovered?` returns true.
  #
  ## env => String
  #
  # Returns the current environment of the application.
  #
  ## logger => Logger
  #
  # Returns your application logger. Is expected to be compatible with the
  # standard library Logger class.
  # @see https://ruby-doc.org/stdlib-2.7.0/libdoc/logger/rdoc/Logger.html
  #
  ## load_application
  #
  # Called upon running `warren consumer start`. Should ensure your application
  # is correctly loaded sufficiently for processing messages
  #
  module FrameworkAdaptor
    # The RailsAdaptor provides error handling and application
    # loading for Rails applications
    class RailsAdaptor
      # Matches errors associated with database connection loss.
      # To understand exactly how this works, we need to go under the hood of
      # `rescue`.
      # When an exception is raised in Ruby, the interpreter begins unwinding
      # the stack, looking for `rescue` statements. For each one it
      # finds it performs the check `ExceptionClass === raised_exception`,
      # and if this returns true, it enters the rescue block, otherwise it
      # continues unwinding the stack.
      # Under normal circumstances Class#=== returns true for instances of that
      # class. Here we override that behaviour and explicitly check for a
      # database connection instead. This ensures that regardless of what
      # exception gets thrown if we loose access to the database, we correctly
      # handle the message
      class ConnectionMissing
        def self.===(_)
          # We used to inspect the exception, and try and check it against a list
          # of errors that might indicate connectivity issues. But this list
          # just grew and grew over time. So instead we just explicitly check
          # the outcome
          !ActiveRecord::Base.connection.active?
        rescue StandardError => _e
          # Unfortunately ActiveRecord::Base.connection.active? can throw an
          # exception if it is unable to connect, and furthermore the class
          # depends on the adapter used.
          true
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
        ActiveRecord::Base.clear_active_connections!
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
