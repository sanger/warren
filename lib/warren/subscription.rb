# frozen_string_literal: true

module Warren
  # Configures and wraps up subscriptions on a Bunny Channel/Queue
  class Subscription
    extend Forwardable

    attr_reader :channel

    #
    # Great a new subscription. Handles queue creation, binding and attaching
    # consumers to the queues
    #
    # @param channel [Warren::Handler::Broadcast::Channel] A channel on which to register queues
    # @param config [Hash] queue configuration hash
    #
    def initialize(channel:, config:)
      @channel = channel
      @queue_name = config.fetch('name')
      @queue_options = config.fetch('options')
      @bindings = config.fetch('bindings')
    end

    def_delegators :channel, :nack, :ack

    #
    # Subscribes to the given queue
    #
    # @param consumer_tag [String] Identifier for the consumer
    #
    # @yieldparam [Bunny::DeliveryInfo] delivery_info Metadata about the delivery
    # @yieldparam [Bunny::MessageProperties] properties
    # @yieldparam [String] payload the contents of the message
    #
    # @return [Bunny::Consumer] The bunny consumer object
    #
    def subscribe(consumer_tag, &block)
      channel.prefetch(10)
      queue.subscribe(manual_ack: true, block: false, consumer_tag: consumer_tag, durable: true, &block)
    end

    # Ensures the queues and channels are set up to receive messages
    # keys: additional routing_keys to bind
    def activate!
      establish_bindings!
    end

    def delay(payload, routing_key:, headers: {}); end

    private

    def add_binding(exchange, options)
      queue.bind(exchange, options)
    end

    def exchange(config)
      channel.exchange(*config.values_at('name', 'options'))
    end

    def queue
      raise StandardError, 'No queue configured' if @queue_name.nil?

      channel.queue(@queue_name, @queue_options)
    end

    def establish_bindings!
      @bindings.each do |binding_config|
        exchange = exchange(binding_config['exchange'])
        transformed_options = merge_routing_key_prefix(binding_config['options'])
        add_binding(exchange, transformed_options)
      end
    end

    def merge_routing_key_prefix(options)
      options.transform_values do |value|
        format(value, routing_key_prefix: channel.routing_key_prefix)
      end
    end
  end
end
