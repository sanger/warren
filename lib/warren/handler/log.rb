# frozen_string_literal: true

require_relative 'base'

module Warren
  module Handler
    # Class Warren::Log provides a dummy RabbitMQ
    # connection pool for use during development
    class Log < Warren::Handler::Base
      # Mimics a {Broadcast::Channel} but instead passes out to a logger
      class Channel
        def initialize(logger, routing_key_template: '%s')
          @logger = logger
          @routing_key_template = routing_key_template
        end

        # Logs `message` to the configured logger
        #
        # @param message [#routing_key,#payload] A message should respond to routing_key and payload.
        #                                        @see Warren::Message::Full
        #
        # @return [Warren::Handler::Broadcast::Channel] returns self for chaining
        #
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

      # Small object to track exchange properties for logging purposes
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
          nil
        end
      end

      attr_reader :logger

      def initialize(logger:, routing_key_prefix: nil)
        super()
        @logger = logger
        @routing_key_template = Handler.routing_key_template(routing_key_prefix)
      end

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
