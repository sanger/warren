# frozen_string_literal: true

module Warren
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
      # exception gets thrown if we loose access to the database, we coreectly
      # handle the message
      class ConnectionMissing
        def self.===(_)
          # We used to inspect the exception, and try and check it against a list
          # of errors that might indicate connectivity issues. But this list
          # just grew and grew over time. So instead we just explicitly check
          # the outcome
          !ActiveRecord::Base.connected?
        end
      end

      def recovered?
        ActiveRecord::Base.connection.reconnect!
        true
      rescue StandardError
        false
      end

      def handle
        ActiveRecord::Base.connection_pool.with_connection do
          yield
        rescue ConnectionMissing => e
          raise Warren::Exceptions::TemporaryIssue, e.message
        end
      end

      def env
        Rails.env
      end

      def logger
        Rails.logger
      end

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
