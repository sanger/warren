# frozen_string_literal: true

module Warren
  module Handler
    # Class Warren::Log provides a dummy RabbitMQ
    # connection pool for use during development
    class Log
      # Mimics a {Bunny::Channel} but instead passes out to a logger
      class Channel
        def initialize(logger, routing_key_template: '%s')
          @logger = logger
          @routing_key_template = routing_key_template
        end

        def <<(message)
          @logger.info "Published: #{key_for(message)}"
          @logger.debug "Payload: #{message.payload}"
          self
        end

        private

        def key_for(message)
          @routing_key_template % message.routing_key
        end
      end

      attr_reader :logger

      def initialize(logger:, routing_key_prefix: nil)
        @logger = logger
        @routing_key_template = Handler.routing_key_template(routing_key_prefix)
      end

      #
      # Provide API compatibility with the RabbitMQ versions
      # Do nothing in this case
      #
      def connect; end

      def disconnect; end

      #
      # Yields a Warren::Log::Channel
      #
      #
      # @return [void]
      #
      # @yieldreturn [Warren::Log::Channel] A rabbitMQ channel that logs messaged to the test warren
      def with_channel
        yield Channel.new(@logger, routing_key_template: @routing_key_template)
      end

      #
      # Sends a message to the log channel.
      # Useful if you only need to send one message.
      #
      # @param [Warren::Message] message The message to broadcast. Must respond to #routing_key and #payload
      #
      # @return [Warren::Log] Returns itself to allow chaining. But you're
      #                       probably better off using #with_channel
      #                       in that case
      #
      def <<(message)
        with_channel { |c| c << message }
      end
    end
  end
end
