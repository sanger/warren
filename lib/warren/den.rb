# frozen_string_literal: true

require 'bunny'
require 'warren/fox'
require 'warren/subscription'

module Warren
  # A Den is in charge of creating a Fox from a consumer configuration
  # Currently its pretty simple, but in future will also handle registration of
  # delay and dead-letter queues/exchanges.
  class Den
    #
    # Create a {Warren::Fox} work pool.
    # @param app_name [String] The name of the application. Corresponds to the
    #                          subscriptions config in `config/warren.yml`
    # @param config [Warren::Config::Consumers] A configuration object, loaded from `config/warren.yml` by default
    # @param adaptor [#recovered?,#handle,#env] An adaptor to handle framework specifics
    def initialize(app_name, config, adaptor:)
      @app_name = app_name
      @config = config
      @fox = nil
      @adaptor = adaptor
    end

    def fox
      @fox ||= spawn_fox
    end

    #
    # Ensures the dead_letter queues and exchanges are registered.
    #
    # @return [Void]
    def register_dead_letter_queues
      config = dead_letter_config
      return unless config

      Warren.handler.with_channel do |channel|
        subscription = Warren::Subscription.new(channel: channel, config: config)
        subscription.activate!
      end
    end

    private

    def consumer_config
      @config.consumer(@app_name)
    end

    #
    # Spawn a new fox
    #
    # @return [Warren::Fox]
    def spawn_fox
      # We don't use with_channel as our consumer persists outside the block,
      # and while we *can* share channels between consumers it results in them
      # sharing the same worker pool. This process lets us control workers on
      # a per-queue basis. Currently that just means one worker per consumer.
      channel = Warren.handler.new_channel
      subscription = Warren::Subscription.new(channel: channel, config: queue_config)
      Warren::Fox.new(name: @app_name,
                      subscription: subscription,
                      adaptor: @adaptor,
                      subscribed_class: subscribed_class)
    end

    def queue_config
      consumer_config.fetch('queue')
    end

    def dead_letter_config
      consumer_config.fetch('dead_letters')
    end

    def subscribed_class
      Object.const_get(consumer_config.fetch('subscribed_class'))
    end
  end
end
