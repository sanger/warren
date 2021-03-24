# frozen_string_literal: true

module Warren
  module Handler
    # Class Warren::Test provides provides a dummy RabbitMQ
    # connection pool for use during testing
    class Test
      DISABLED_WARNING = <<~DISABLED_WARREN
        Test made against a disabled warren.
        Warren::Handler::Test must be explicitly enabled to track messages,
        it is a good idea to disable it again after testing the relevant
        behaviour. This ensures we track messages on a per-test basis, and
        avoids unnecessary message storage.

        If using rspec it is suggested that you add the following to your
        spec_helper.rb

        config.around(:each, warren: true) do |ex|
          Warren.handler.enable!
          ex.run
          Warren.handler.disable!
        end

        You can then tag tests with warren: true to enable warren testing.
      DISABLED_WARREN
      # Stand in for {Bunny::Channel}, provides a store of messages to use
      # in test assertions
      class Channel
        def initialize(warren)
          @warren = warren
        end

        def <<(message)
          @warren << message
        end
      end

      #
      # Creates a test warren with no messages.
      # Test warrens are shared across all threads.
      #
      # @param [_] _args Configuration arguments are ignored.
      #
      def initialize(*_args)
        @messages = []
        @enabled = false
      end

      #
      # Provide API compatibility with the RabbitMQ versions
      # Do nothing in this case
      #
      def connect; end

      def disconnect; end

      #
      # Yields an exchange which gets returned to the pool on block closure
      #
      #
      # @return [void]
      #
      # @yieldreturn [Warren::Test::Channel] A rabbitMQ channel that logs messaged to the test warren
      def with_channel
        yield Channel.new(self)
      end

      def clear_messages
        @messages = []
      end

      def last_message
        messages.last
      end

      def message_count
        messages.length
      end

      def messages_matching(routing_key)
        messages.count { |message| message.routing_key == routing_key }
      end

      def enable!
        @enabled = true
        clear_messages
      end

      # Clean up after ourselves to avoid memory leaks
      def disable!
        @enabled = false
        clear_messages
      end

      def messages
        raise_if_not_tracking
        @messages
      end

      # Disable message logging if not required
      def <<(message)
        @messages << message if @enabled
      end

      private

      def raise_if_not_tracking
        raise StandardError, DISABLED_WARNING unless @enabled
      end
    end
  end
end