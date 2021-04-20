# frozen_string_literal: true

module Warren
  module Handler
    # Class Warren::Log provides a dummy RabbitMQ
    # connection pool for use during development
    class Log
      # Mimics a {Broadcast::Channel} but instead passes out to a logger
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

        def exchange(name, options)
          @logger.debug "Declared exchange: #{name}, #{options.inspect}"
          Exchange.new(name, options)
        end

        def queue(name, options)
          @logger.debug "Declared queue: #{name}, #{options.inspect}"
          Queue.new(@logger, name)
        end

        # NOOP - Provided for API compatibility
        def prefetch(number); end

        private

        def key_for(message)
          @routing_key_template % message.routing_key
        end
      end

      Exchange = Struct.new(:name, :options)

      # Queue class to provide extended logging in development mode
      class Queue
        def initialize(logger, name)
          @logger = logger
          @name = name
        end

        def bind(exchange, options)
          @logger.debug "Bound queue #{@name}: #{exchange}, #{options.inspect}"
        end

        def subscribe(options)
          @logger.debug "Subscribed to queue #{@name}: #{options.inspect}"
          @logger.warn 'This is a Warren::Handler::Log no messages will be processed'
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

      def new_channel
        Channel.new(@logger, routing_key_template: @routing_key_template)
      end

      #
      # Yields a Warren::Log::Channel
      #
      #
      # @return [void]
      #
      # @yieldreturn [Warren::Log::Channel] A rabbitMQ channel that logs messaged to the test warren
      def with_channel
        yield new_channel
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
