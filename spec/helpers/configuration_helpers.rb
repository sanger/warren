# frozen_string_literal: true

# Shared configuration examples to ensure that our unit tests share the same
# interfaces
module Configuration
  # Returns a full warren consumers example
  def self.warren_consumers
    {
      'existing_consumer' => {},
      'name' => topic_exchange_consumer
    }
  end

  # Returns a full topic-exchange consumer configuration
  def self.topic_exchange_consumer(subscribed_class: 'Warren::Subscriber::Name')
    {
      'desc' => 'description',
      'queue' => topic_exchange_queue,
      'dead_letters' => dead_letter_configuration,
      'subscribed_class' => subscribed_class,
      'delay' => {},
      'worker_count' => 3
    }
  end

  def self.topic_exchange_queue
    {
      'name' => 'queue_name',
      'options' => { durable: true, arguments: { 'x-dead-letter-exchange' => 'name.dead-letters' } },
      'bindings' => topic_exchange_bindings
    }
  end

  # Returns a single binding
  def self.topic_exchange_bindings
    [
      {
        'exchange' => { 'name' => 'exchange_name', 'options' => { type: 'topic', durable: true } },
        # Match the format we suggest to the user in lib/warren/app/exchange_config.rb
        'options' => { routing_key: '%{routing_key_prefix}.c' } # rubocop:disable Style/FormatStringToken
      }
    ]
  end

  # Queue configuration for dead-letters
  def self.dead_letter_configuration
    {
      'name' => 'name.dead-letters',
      'options' => { durable: true, arguments: {} },
      'bindings' => [{
        'exchange' => { 'name' => 'name.dead-letters', 'options' => { type: 'fanout', durable: true } },
        'options' => {}
      }]
    }
  end

  # Contrary to subscriptions, delay exchanges are exchange based
  def self.delay_exchange_configuration(
    exchange_name: 'name.delay',
    queue_name: 'name.delay',
    ttl: 30_000,
    original_queue: 'queue_name'
  )
    {
      'exchange' => { 'name' => exchange_name, 'options' => { type: 'fanout', durable: true } },
      'bindings' => [{
        'queue' => { 'name' => queue_name, 'options' => {
          durable: true, arguments: {
            'x-dead-letter-exchange' => '', 'x-message-ttl' => ttl, 'x-dead-letter-routing-key' => original_queue
          }
        } }, 'options' => {}
      }]
    }
  end

  def self.delay_exchange_consumer(subscribed_class: 'Warren::Subscriber::Name')
    {
      'desc' => 'description',
      'queue' => topic_exchange_queue,
      'dead_letters' => dead_letter_configuration,
      'subscribed_class' => subscribed_class,
      'delay' => delay_exchange_configuration,
      'worker_count' => 3
    }
  end
end
