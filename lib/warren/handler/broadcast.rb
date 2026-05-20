# frozen_string_literal: true

require 'bunny'
require 'forwardable'
require 'connection_pool'
require_relative 'base'
require_relative '../exceptions'

module Warren
  module Handler
    #
    # Class Warren::Broadcast provides a connection pool of
    # threadsafe RabbitMQ channels for broadcasting messages
    #
    class Broadcast < Warren::Handler::Base
      MAX_START_SESSION_DELAY = 5 * 60 # default seconds for exponential backoff
      MAX_START_SESSION_ATTEMPTS = 30 # default max count before giving up

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
      # @param [Hash] kwargs Any additional keyword arguments from configuration.
      def initialize(exchange:, routing_key_prefix:, server: {}, pool_size: 14, **kwargs)
        super()
        @server = server
        @exchange_name = exchange
        @pool_size = pool_size
        @routing_key_prefix = routing_key_prefix
        @max_start_session_delay = kwargs[:max_start_session_delay] || MAX_START_SESSION_DELAY
        @max_start_session_attempts = kwargs[:max_start_session_attempts] || MAX_START_SESSION_ATTEMPTS
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

      def new_channel(worker_count: 1)
        Channel.new(session.create_channel(nil, worker_count), exchange: @exchange_name,
                                                               routing_key_prefix: @routing_key_prefix)
      end

      private

      def server_connection
        ENV.fetch('WARREN_CONNECTION_URI', @server)
      end

      # Creates or retrieves the Bunny session for RabbitMQ communication.
      #
      # @note using default parameters for the Bunny connection such as
      # :automatically_recover (boolean, default: true): when false, will
      #   disable automatic network failure recovery
      # :network_recovery_interval (number, default: 5.0): interval between
      #   reconnection attempts
      # :heartbeat or :heartbeat_interval (string or integer, default: :server):
      #   standard RabbitMQ server heartbeat. :server means "use the value
      #   from RabbitMQ config". 0 means no heartbeats (not recommended).
      #
      # @note :automatically_recover option is used after the initial
      #   connection is established. If the connection cannot be established
      #   in the first place, it will raise an exception and not retry.
      #   Therefore, the initial connection is retried separately in the
      #   start_session method of this handler.
      #
      # @see http://rubybunny.info/articles/connecting.html
      #
      # @return [Bunny::Session] The Bunny session object used to manage the
      #   connection to RabbitMQ.
      def session
        @session ||= Bunny.new(server_connection)
      end

      def connection_pool
        @connection_pool ||= start_session && ConnectionPool.new(size: @pool_size, timeout: 5) do
          new_channel
        end
      end

      # Starts the Bunny session with retry logic for connection failures.
      #
      # @note Exponential backoff: 1, 2, 4, 8, ... seconds,
      #   capped at {@max_start_session_delay} and
      #   up to {@max_start_session_attempts} attempts before giving up.
      #
      # @return [true] Returns true if the session starts successfully.
      # @raise [Warren::Exceptions::SessionStartError] if the Bunny session
      #   cannot be started after {@max_start_session_attempts} attempts.
      # rubocop:disable Metrics/MethodLength
      def start_session
        attempts = 0
        begin
          session.start
        rescue Bunny::Exception, Errno::ECONNREFUSED, Errno::ETIMEDOUT => e
          attempts += 1
          if attempts >= @max_start_session_attempts
            error_message = "Failed to start session (#{e.class}): #{e.message}, attempts: #{attempts}, giving up."
            raise Warren::Exceptions::SessionStartError, error_message
          end

          wait = [2**(attempts - 1), @max_start_session_delay].min
          $stdout.puts(
            "Failed to start session (#{e.class}): #{e.message}, " \
            "attempts: #{attempts}, retrying in #{wait}s..."
          )
          sleep wait
          retry # Go to begin block
        end
        true
      end
      # rubocop:enable Metrics/MethodLength

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
