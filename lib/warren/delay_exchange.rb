# frozen_string_literal: true

module Warren
  # Configures and wraps up delay exchange on a Bunny Channel/Queue
  # A delay exchange routes immediately onto a queue with a ttl
  # once messages on this queue expire they are dead-lettered back onto
  # to original exchange
  # Note: This does not currently support the rabbitmq-delayed-message-exchange
  # plugin.
  class DelayExchange
    extend Forwardable

    attr_reader :channel

    #
    # Create a new delay exchange. Handles queue creation, binding and attaching
    # consumers to the queues
    #
    # @param channel [Warren::Handler::Broadcast::Channel] A channel on which to register queues
    # @param config [Hash] queue configuration hash
    #
    def initialize(channel:, config:)
      @channel = channel
      @exchange_config = config&.fetch('exchange', nil)
      @bindings = config&.fetch('bindings', [])
    end

    def_delegators :channel, :nack, :ack

    # Ensures the queues and channels are set up to receive messages
    # keys: additional routing_keys to bind
    def activate!
      establish_bindings!
    end

    #
    # Post a message to the delay exchange.
    #
    # @param payload [String] The message payload
    # @param routing_key [String] The routing key of the re-sent message
    # @param headers [Hash] A hash of headers. Typically: { attempts: <Integer> }
    # @option headers [Integer] :attempts The number of times the message has been processed
    #
    # @return [Void]
    #
    def publish(payload, routing_key:, headers: {})
      raise StandardError, 'No delay queue configured' unless configured?

      message = Warren::Message::Simple.new(routing_key, payload, headers)
      channel.publish(message, exchange: exchange)
    end

    private

    def configured?
      @exchange_config&.key?('name')
    end

    def add_binding(queue, options)
      queue.bind(exchange, options)
    end

    def exchange
      @exchange ||= channel.exchange(*@exchange_config.values_at('name', 'options'))
    end

    def queue(config)
      channel.queue(*config.values_at('name', 'options'))
    end

    def establish_bindings!
      @bindings.each do |binding_config|
        queue = queue(binding_config['queue'])
        transformed_options = merge_routing_key_prefix(binding_config['options'])
        add_binding(queue, transformed_options)
      end
    end

    def merge_routing_key_prefix(options)
      options.transform_values do |value|
        format(value, routing_key_prefix: channel.routing_key_prefix)
      end
    end
  end
end
