# frozen_string_literal: true

require 'bunny'
require 'forwardable'
require 'connection_pool'
require_relative 'base'

require 'ruby-prof'


module Warren
  module Handler
    #
    # Class Warren::Broadcast provides a connection pool of
    # threadsafe RabbitMQ channels for broadcasting messages
    #
    class Broadcast < Warren::Handler::Base
      # Wraps a Bunny::Channel
      # @see https://rubydoc.info/gems/bunny/Bunny/Channel
      class Channel
        extend Forwardable

        attr_reader :routing_key_prefix

        def_delegators :@bun_channel, :close, :exchange, :queue, :prefetch, :ack, :nack

        def initialize(bun_channel, routing_key_prefix:, exchange: nil)
          @bun_channel = bun_channel
          @exchange_name = exchange
          @routing_key_prefix = routing_key_prefix
          @routing_key_template = Handler.routing_key_template(routing_key_prefix)
        end

        # Publishes `message` to the configured exchange
        #
        # @param message [#routing_key,#payload] A message should respond to routing_key and payload.
        #                                        @see Warren::Message::Full
        #
        # @return [Warren::Handler::Broadcast::Channel] returns self for chaining
        #
        def <<(message)
          publish(message)
        end

        # Publishes `message` to `exchange` (Defaults to configured exchange)
        #
        # @param message [#routing_key,#payload] A message should respond to routing_key and payload.
        #                                        @see Warren::Message::Full
        # @param exchange [Bunny::Exchange] The exchange to publish to
        #
        # @return [Warren::Handler::Broadcast::Channel] returns self for chaining
        #
        def publish(message, exchange: configured_exchange)
          exchange.publish(message.payload, routing_key: key_for(message), headers: message.headers)
          self
        end

        private

        def configured_exchange
          raise StandardError, 'No exchange configured' if @exchange_name.nil?

          @configured_exchange ||= exchange(@exchange_name, auto_delete: false, durable: true, type: :topic)
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
        super()
        @server = server
        @exchange_name = exchange
        @pool_size = pool_size
        @routing_key_prefix = routing_key_prefix
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
      # NB: connection_pool used here is returned from the connection_pool method.
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
        result = RubyProf.profile do
          with_channel { |channel| channel << message }
        end
        # print a graph profile to text
        printer = RubyProf::GraphPrinter.new(result)
        printer.print($stdout, {})
        self
      end

      def new_channel(worker_count: 1)
        Channel.new(session.create_channel(nil, worker_count), exchange: @exchange_name,
                                                               routing_key_prefix: @routing_key_prefix)
      end

      private

      def server_connection
        ENV.fetch('WARREN_CONNECTION_URI', @server)
      end

      def session
        @session ||= Bunny.new(server_connection)
      end

      # Returns a pool of Bunny::Channels.
      # Ref: https://github.com/mperham/connection_pool?tab=readme-ov-file#usage
      def connection_pool
        @connection_pool ||= start_session && ConnectionPool.new(size: @pool_size, timeout: 5) do
          new_channel
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
