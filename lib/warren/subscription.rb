# frozen_string_literal: true

module Warren
  # Configures and wraps up subscriptions on a Bunny Channel/Queue
  class Subscription
    extend Forwardable

    attr_reader :channel

    def initialize(channel:, config:)
      @channel = channel
      @queue_name = config.dig('queue', 'name')
      @queue_options = config.dig('queue', 'options')
      @bindings = config.dig('queue', 'bindings')
    end

    def_delegators :channel, :nack, :ack

    def subscribe(consumer_tag, &block)
      channel.prefetch(10)
      queue.subscribe(manual_ack: true, block: false, consumer_tag: consumer_tag, durable: true, &block)
    end

    # Ensures the queues and channels are set up to receive messages
    # keys: additional routing_keys to bind
    def activate!
      establish_bindings!
    end

    def add_binding(exchange, options)
      queue.bind(exchange, options)
    end

    private

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
        add_binding(exchange, binding_config['options'])
      end
    end
  end
end
