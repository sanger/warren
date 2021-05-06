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
      'subscribed_class' => subscribed_class
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
        # Suggested cop style of %<routing_key_prefix>s but prefer suggesting the simpler option as it
        # would be all to easy to miss out the 's', resulting in varying behaviour depending on the following
        # character
        # rubocop:disable Style/FormatStringToken
        'options' => { routing_key: '%{routing_key_prefix}.c' }
        # rubocop:enable Style/FormatStringToken
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
end
