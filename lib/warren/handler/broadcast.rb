# frozen_string_literal: true

require 'bunny'
require 'forwardable'

module Warren
  module Handler
    #
    # Class Warren::Broadcast provides a connection pool of
    # threadsafe RabbitMQ channels for broadcasting messages
    #
    class Broadcast
      # Wraps a Bunny::Channel
      # @see https://rubydoc.info/gems/bunny/Bunny/Channel
      class Channel
        extend Forwardable

        def_delegators :@bun_channel, :close, :exchange, :queue, :prefetch, :ack, :nack

        def initialize(bun_channel, routing_key_template:, exchange: nil)
          @bun_channel = bun_channel
          @exchange_name = exchange
          @routing_key_template = routing_key_template
        end

        def <<(message)
          default_exchange.publish(message.payload, routing_key: key_for(message))
          self
        end

        private

        def default_exchange
          raise StandardError, 'No exchange configured' if @exchange_name.nil?

          @default_exchange ||= exchange(@exchange_name, auto_delete: false, durable: true, type: :topic)
        end

        def key_for(message)
          @routing_key_template % message.routing_key
        end
      end

      #
      # Creates a warren but does not connect.
      #
      # @param [Hash] server Server config options passes straight to Bunny
      # @param [String] exchange The name of the exchange to connect to
      # @param [Integer] pool_size The connection pool size
      # @param [String,nil] routing_key_prefix The prefix to pass before the routing key.
      #                                        Can be used to ensure environments remain distinct.
      def initialize(exchange:, routing_key_prefix:, server: {}, pool_size: 14)
        @server = server
        @exchange_name = exchange
        @pool_size = pool_size
        @routing_key_template = Handler.routing_key_template(routing_key_prefix)
      end

      #
      # Opens a connection to the RabbitMQ server. Will need to be re-initialized after forking.
      #
      # @return [true] We've connected!
      #
      def connect
        reset_pool
        start_session
      end

      #
      # Closes the connection. Call before forking to avoid leaking connections
      #
      #
      # @return [true] We've disconnected
      #
      def disconnect
        close_session
      end

      #
      # Yields an {Warren::Handler::Broadcast::Channel} which gets returned to the pool on block closure
      #
      # @return [void]
      #
      # @yieldparam [Warren::Handler::Broadcast::Channel] A rabbitMQ channel that sends messages to the configured
      #                                                    exchange
      def with_channel(&block)
        connection_pool.with(&block)
      end

      #
      # Borrows a RabbitMQ channel, sends a message, and immediately returns it again.
      # Useful if you only need to send one message.
      #
      # @param [Warren::Message] message The message to broadcast. Must respond to #routing_key and #payload
      #
      # @return [Warren::Handler::Broadcast] Returns itself to allow chaining. But you're
      #                             probably better off using #with_channel
      #                             in that case
      #
      def <<(message)
        with_channel { |channel| channel << message }
        self
      end

      private

      def session
        @session ||= Bunny.new(@server)
      end

      def connection_pool
        @connection_pool ||= start_session && ConnectionPool.new(size: @pool_size, timeout: 5) do
          Channel.new(session.create_channel, exchange: @exchange_name,
                                              routing_key_template: @routing_key_template)
        end
      end

      def start_session
        session.start
        true
      end

      def close_session
        reset_pool
        @session&.close
        @session = nil
      end

      def reset_pool
        @connection_pool&.shutdown { |ch| ch.close }
        @connection_pool = nil
      end
    end
  end
end
