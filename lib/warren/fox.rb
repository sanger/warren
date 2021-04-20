# frozen_string_literal: true

require 'forwardable'
require 'bunny'
require 'warren'
require 'warren/helpers/state_machine'
require 'warren/subscriber/base'
require 'warren/log_tagger'
require 'warren/framework_adaptor/rails_adaptor'

module Warren
  # A fox is a rabbitMQ consumer. It handles subscription to the queue
  # and passing message on to the registered Subscriber
  class Fox
    FOX = '🦊'

    extend Forwardable
    extend Warren::Helpers::StateMachine
    # Maximum wait time between database retries: 5 minutes
    MAX_RECONNECT_DELAY = 60 * 5

    attr_reader :state, :subscription, :consumer_tag

    #
    # Creates a fox, a RabbitMQ consumer.
    # Subscribes to the queues defined in `subscription`
    # and passes messages on to the subscriber
    #
    # @param name [String] The name of the consumer
    # @param subscription [Warren::Subscription] Describes the queue to subscribe to
    # @param env [String] A string identifying the environment
    # @param adaptor [#recovered?,#handle,#env] An adaptor to handle framework specifics
    #
    def initialize(name:, subscription:, adaptor:)
      @consumer_tag = "#{adaptor.env}_#{name}_#{Process.pid}"
      @state = :initialized
      @subscription = subscription
      @logger = Warren::LogTagger.new(logger: adaptor.logger, tag: "#{FOX} #{@consumer_tag}")
      @adaptor = adaptor
    end

    states :stopping, :stopped, :paused, :starting, :started, :running
    def_delegators :@logger, :warn, :info, :error, :debug

    def run!
      starting!
      subscription.activate! # Set up the queues
      running!            # Transition to running state
      subscribe!          # Subscribe to the queue

      info { 'Started consumer' }
    end

    def stop!
      info { 'Stopping consumer' }
      stopping!
      unsubscribe!
      info { 'Stopped consumer' }
      stopped!
    end

    def pause!
      return unless running?

      unsubscribe!
      @recovery_attempts = 0
      @recover_at = Time.now
      paused!
    end

    # Rest for database recovery and restore the consumer.
    def attempt_recovery
      return unless paused? && recovery_due?

      warn { "Attempting recovery: #{@recovery_attempts}" }
      if recovered?
        running!
        subscribe!
      else
        @recovery_attempts += 1
        @recover_at = Time.now + delay_for_attempt
      end
    end

    private

    # Our consumer operates in another thread. It is non blocking.
    def subscribe!
      raise StandardError, 'Consumer already exists' unless @consumer.nil?

      @consumer = @subscription.subscribe(@consumer_tag) do |delivery_info, metadata, payload|
        process(delivery_info, metadata, payload)
      end
    end

    # Cancels the consumer and unregisters it
    def unsubscribe!
      info { 'Unsubscribing' }
      @consumer&.cancel
      @consumer = nil
      info { 'Unsubscribed' }
    end

    def delay_for_attempt
      [2**@recovery_attempts, MAX_RECONNECT_DELAY].min
    end

    def recovery_due?
      Time.now > @recover_at
    end

    def recovered?
      @adaptor.recovered?
    end

    def process(delivery_info, metadata, payload)
      log_message(payload) do
        message = Warren::Subscriber::Base.new(self, delivery_info, metadata, payload)
        @adaptor.handle { message._process_ }
      rescue Warren::Exceptions::TemporaryIssue => e
        warn { "Temporary Issue: #{e.message}" }
        pause!
        message.requeue(e)
      rescue StandardError => e
        message.dead_letter(e)
      end
    end

    def log_message(payload)
      debug { 'Started message process' }
      debug { payload }
      yield
    ensure
      debug { 'Finished message process' }
    end
  end
end
