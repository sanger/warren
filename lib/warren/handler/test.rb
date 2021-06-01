# frozen_string_literal: true

require_relative 'base'

module Warren
  module Handler
    # Class Warren::Test provides provides a dummy RabbitMQ
    # connection pool for use during testing.
    #
    # = Set up a test warren
    #
    # By default, the test warren is disabled during testing to avoid storing
    # messages unnecessarily. Instead you must explicitly enable it when you
    # wish to test message receipt.
    #
    # If using rspec it is suggested that you add the following to your
    # spec_helper.rb
    #
    #   config.around(:each, warren: true) do |ex|
    #     Warren.handler.enable!
    #     ex.run
    #     Warren.handler.disable!
    #   end
    #
    # = Making assertions
    #
    # It is possible to query the test warren about the messages it has seen.
    # In particular the following methods are useful:
    #
    # {render:#messages}
    #
    # {render:#last_message}
    #
    # {render:#message_count}
    #
    # {render:#messages_matching}
    #
    # = Example
    #
    #   describe QcResult, warren: true do
    #     let(:warren) { Warren.handler }
    #
    #     setup { warren.clear_messages }
    #     let(:resource) { build :qc_result }
    #     let(:routing_key) { 'test.message.qc_result.' }
    #
    #     it 'broadcasts the resource' do
    #       resource.save!
    #       expect(warren.messages_matching(routing_key)).to eq(1)
    #     end
    #   end
    class Test < Warren::Handler::Base
      # Warning displayed if the user attempts to make assertions against the
      # handler without having enabled it.
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
      # Stand in for {Broadcast::Channel}, provides a store of messages to use
      # in test assertions
      class Channel
        def initialize(warren)
          @warren = warren
        end

        # Records `message` for testing purposes
        #
        # @param message [#routing_key,#payload] A message should respond to routing_key and payload.
        #                                        @see Warren::Message::Full
        #
        # @return [Warren::Handler::Broadcast::Channel] returns self for chaining
        #
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
        super()
        @messages = []
        @exchanges = []
        @enabled = false
      end

      #
      # Yields a new channel, which proxies all message back to {messages} on the
      # {Warren::Handler::Test}
      #
      # @return [void]
      #
      # @yieldreturn [Warren::Test::Channel] A rabbitMQ channel that logs messaged to the test warren
      def with_channel
        yield new_channel
      end

      #
      # Returns a new channel, which proxies all message back to {messages} on the
      # {Warren::Handler::Test}
      #
      # @return [Warren::Test::Channel] A rabbitMQ channel that logs messaged to the test warren
      #
      def new_channel
        Channel.new(@logger, routing_key_template: @routing_key_template)
      end

      #
      # Clear any logged messaged
      #
      # @return [Array] The new empty array, lacking messages
      #
      def clear_messages
        @messages = []
        @exchanges = []
      end

      #
      # Returns the last message received by the warren
      #
      # @return [#routing_key#payload] The last message object received by the warren
      #
      def last_message
        messages.last
      end

      #
      # Returns the total number message received by the warren since it was enabled
      #
      # @return [Integer] The total number of messages
      #
      def message_count
        messages.length
      end

      #
      # Returns the total number message received by the warren matching the given
      # routing_key since it was enabled
      #
      # @param routing_key [String] The routing key to filter by
      #
      # @return [Integer] The number of matching messages
      #
      def messages_matching(routing_key)
        messages.count { |message| message.routing_key == routing_key }
      end

      # Enable the warren
      def enable!
        @enabled = true
        clear_messages
      end

      # Clean up after ourselves to avoid memory leaks
      def disable!
        @enabled = false
        clear_messages
      end

      # Returns an array of all message received by the warren since it was enabled
      #
      # @return [Array<#routing_key#payload>] All received messages
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
