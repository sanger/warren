# frozen_string_literal: true

require 'forwardable'
require 'bunny'
require 'digest'
require 'warren'
require 'warren/helpers/state_machine'
require 'warren/subscriber/base'
require 'warren/log_tagger'
require 'warren/framework_adaptor/rails_adaptor'

module Warren
  # A fox is a rabbitMQ consumer. It handles subscription to the queue
  # and passing message on to the registered Subscriber
  # rubocop:disable Metrics/ClassLength
  class Fox
    # A little cute fox emoji to easily flag output from the consumers
    FOX = '🦊'

    extend Forwardable
    extend Warren::Helpers::StateMachine
    # Maximum wait time between database retries: 5 minutes
    MAX_RECONNECT_DELAY = 60 * 5

    attr_reader :state, :subscription, :consumer_tag, :delayed

    #
    # Creates a fox, a RabbitMQ consumer.
    # Subscribes to the queues defined in `subscription`
    # and passes messages on to the subscriber
    #
    # @param name [String] The name of the consumer
    # @param subscription [Warren::Subscription] Describes the queue to subscribe to
    # @param adaptor [#recovered?,#handle,#env] An adaptor to handle framework specifics
    # @param subscribed_class [Warren::Subscriber::Base] The class to process received messages
    # @param delayed [Warren::DelayExchange] The details handling delayed message broadcast
    #
    def initialize(name:, subscription:, adaptor:, subscribed_class:, delayed:)
      @consumer_tag = "#{adaptor.env}_#{name}_#{Process.pid}"
      @subscription = subscription
      @delayed = delayed
      @logger = Warren::LogTagger.new(logger: adaptor.logger, tag: "#{FOX} #{@consumer_tag}")
      @adaptor = adaptor
      @subscribed_class = subscribed_class
      @state = :initialized
      # Remember messages that could not be dead-lettered because RabbitMQ had
      # already closed the channel, so they can be dead-lettered if redelivered.
      @pending_dead_letter_messages = Set.new
    end

    states :stopping, :stopped, :paused, :starting, :started, :running
    def_delegators :@logger, :warn, :info, :error, :debug

    #
    # Starts up the fox, automatically registering the configured queues and bindings
    # before subscribing to the queue.
    #
    # @return [Void]
    #
    def run!
      starting!
      subscription.activate! # Set up the queues
      delayed.activate!
      running!            # Transition to running state
      subscribe!          # Subscribe to the queue

      info { 'Started consumer' }
    end

    #
    # Stop the consumer and unsubscribes from the queue. Blocks until fully unsubscribed.
    #
    # @return [Void]
    #
    def stop!
      info { 'Stopping consumer' }
      stopping!
      unsubscribe!
      info { 'Stopped consumer' }
      stopped!
    end

    #
    # Temporarily unsubscribes the consumer, and schedules an attempted recovery.
    # Recovery is triggered by the {#attempt_recovery} method which gets called
    # periodically by {Warren::Client}
    #
    # @return [Void]
    #
    def pause!
      return unless running?

      unsubscribe!
      @recovery_attempts = 0
      @recover_at = Time.now
      paused!
    end

    # If the fox is paused and a recovery attempt is due, asks the framework
    # adaptor whether recovery has succeeded (such as reconnecting to the
    # database). If so, it reopens its subscriptions and resubscribes;
    # otherwise a further recovery attempt will be scheduled. Successive
    # recovery attempts will be gradually further apart, up to the
    # MAX_RECONNECT_DELAY of 5 minutes.
    def attempt_recovery
      return unless paused? && recovery_due?

      warn { "Attempting recovery: #{@recovery_attempts}" }
      if recovered?
        recover_subscriptions!
      else
        schedule_recovery_attempt
      end
    end

    # Returns whether a Bunny consumer is currently registered for this fox.
    #
    # Used by the client control loop to detect in-process cases where the fox
    # is marked running but has no active consumer.
    #
    # @return [Boolean]
    def consumer_present?
      !@consumer.nil?
    end

    private

    # Our consumer operates in another thread. It is non blocking.
    def subscribe!
      raise StandardError, 'Consumer already exists' unless @consumer.nil?

      @consumer = @subscription.subscribe(@consumer_tag) do |delivery_info, properties, payload|
        process(delivery_info, properties, payload)
      end
    end

    # Cancels the consumer and un-registers it
    def unsubscribe!
      info { 'Unsubscribing' }
      @consumer&.cancel
    rescue Bunny::Exception, Timeout::Error => e
      warn { "Unsubscribe skipped (channel likely closed): #{e.class}: #{e.message}" }
    ensure
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

    # Processes one delivered message.
    #
    # Flow:
    # 1. Build a subscriber message wrapper.
    # 2. If payload is marked pending dead-letter, force dead-letter.
    # 3. Otherwise run subscriber processing + ack.
    # 4. On {Warren::Exceptions::TemporaryIssue}, pause and requeue.
    # 5. On any other error, log and dead-letter.
    #
    # @param delivery_info [Bunny::DeliveryInfo] Delivery metadata from Bunny
    # @param properties [Bunny::MessageProperties] Message properties and headers
    # @param payload [String] Raw message payload
    # @return [void]
    def process(delivery_info, properties, payload)
      message = @subscribed_class.new(self, delivery_info, properties, payload)

      log_message(payload) do
        handle_message(message, payload)
      end
    rescue Warren::Exceptions::TemporaryIssue => e
      handle_temporary_issue(message, e)
    rescue StandardError => e
      # If RabbitMQ closes the channel before ack succeeds, that error is
      # treated as a message handling failure as well.
      handle_message_failure(message, e)
    end

    # Routes a message through pending-dead-letter handling or normal
    # processing, depending on whether it was previously marked as pending.
    #
    # @param message [Warren::Subscriber::Base] The message wrapper
    # @param payload [String] The raw message payload
    # @return [void]
    def handle_message(message, payload)
      return force_pending_dead_letter(message) if pending_dead_letter?(payload)

      process_message(message)
    end

    # Handles temporary processing failures by pausing and requesting requeue.
    #
    # @param message [Warren::Subscriber::Base] The message wrapper
    # @param exception [StandardError] The temporary failure
    # @return [void]
    def handle_temporary_issue(message, exception)
      warn { "Temporary Issue: #{exception.message}" }
      pause!
      safe_requeue(message, exception)
    end

    # Handles non-temporary failures by logging and requesting dead-letter.
    #
    # @param message [Warren::Subscriber::Base] The message wrapper
    # @param exception [StandardError] The failure that occurred
    # @return [void]
    def handle_message_failure(message, exception)
      error { "Message handling failed: #{exception.class}: #{exception.message}" }
      debug { exception.backtrace.join("\n") } if exception.backtrace
      safe_dead_letter(message, exception)
    end

    # Returns whether the payload is marked as pending dead-letter.
    #
    # @param payload [String] The raw message payload
    # @return [Boolean]
    def pending_dead_letter?(payload)
      @pending_dead_letter_messages.include?(compute_message_identifier(payload))
    end

    # Forces dead-letter for a message previously marked as pending.
    #
    # @param message [Warren::Subscriber::Base] The message wrapper
    # @return [void]
    def force_pending_dead_letter(message)
      warn { 'Re-processing pending dead-letter message after channel re-established; forcing dead-letter' }
      safe_dead_letter(message, StandardError.new('Forced dead-letter after prior channel-closed nack failure'))
    end

    # Runs subscriber processing and final ack via the framework adaptor.
    #
    # @param message [Warren::Subscriber::Base] The message wrapper
    # @return [void]
    def process_message(message)
      @adaptor.handle { message._process_ }
    end

    # Requeues a message after a temporary failure.
    #
    # If RabbitMQ has already closed the channel, Bunny can raise while
    # requeueing. In that case we log the failure and let broker redelivery
    # happen after recovery instead of crashing the consumer.
    #
    # @param message [Warren::Subscriber::Base] The message wrapper to requeue
    # @param exception [StandardError] The exception that triggered requeueing
    # @return [void]
    def safe_requeue(message, exception)
      message.requeue(exception)
    rescue Bunny::Exception, Timeout::Error => e
      warn { "Requeue failed (channel likely closed): #{e.class}: #{e.message}" }
    end

    # Dead-letters a message after a permanent failure.
    #
    # If RabbitMQ has already closed the channel, Bunny can raise while
    # dead-lettering. In that case we remember the message so it can be
    # forced to dead-letter if the broker redelivers it after recovery.
    #
    # @param message [Warren::Subscriber::Base] The message wrapper to dead-letter
    # @param exception [StandardError] The exception that triggered dead-lettering
    # @return [void]
    def safe_dead_letter(message, exception)
      message_identifier = compute_message_identifier(message.payload)
      message.dead_letter(exception)
      # Dead-letter succeeded, remove from pending if present
      @pending_dead_letter_messages.delete(message_identifier)
    rescue Bunny::Exception, Timeout::Error => e
      message_identifier = compute_message_identifier(message.payload)
      warn { "Dead-letter failed (channel likely closed): #{e.class}: #{e.message}" }
      @pending_dead_letter_messages.add(message_identifier)
      pause!
    end

    # Computes a stable identifier for a message payload.
    #
    # Used to track messages whose dead-letter operation failed because the
    # channel had already closed, so they can be recognized if redelivered.
    #
    # @param payload [String] The raw message payload
    # @return [String] SHA256 digest for the payload
    def compute_message_identifier(payload)
      Digest::SHA256.hexdigest(payload)
    end

    # Rebuilds subscription state after a successful recovery check.
    #
    # Reopens the subscription and delay exchange on healthy channels,
    # re-establishes their bindings, and resubscribes the consumer. If any
    # step fails, schedules another recovery attempt.
    #
    # @return [void]
    def recover_subscriptions!
      warn { 'Attempting subscription recovery' }
      restore_subscriptions!
      info { 'Consumer recovered and resubscribed' }
    rescue StandardError => e
      handle_recovery_failure(e)
    end

    # Performs the recovery steps required to restore consumption.
    #
    # Reopens channel-bound objects, reactivates their bindings, transitions
    # back to running state, and subscribes a new consumer.
    #
    # @return [void]
    def restore_subscriptions!
      subscription.reopen!
      delayed.reopen!(channel: subscription.channel)
      subscription.activate!
      delayed.activate!
      running!
      subscribe!
    end

    # Logs a recovery failure and schedules the next retry attempt.
    #
    # @param exception [StandardError] The recovery failure
    # @return [void]
    def handle_recovery_failure(exception)
      warn { "Recovery failed: #{exception.class}: #{exception.message}" }
      debug { exception.backtrace.join("\n") } if exception.backtrace
      schedule_recovery_attempt
    end

    # Schedules the next recovery attempt using exponential backoff.
    #
    # Increments the attempt counter and sets the next recovery time based on
    # {#delay_for_attempt}, capped by {MAX_RECONNECT_DELAY}.
    #
    # @return [void]
    def schedule_recovery_attempt
      @recovery_attempts += 1
      @recover_at = Time.now + delay_for_attempt
    end

    def log_message(payload)
      debug { 'Started message process' }
      debug { payload }
      yield
    ensure
      debug { 'Finished message process' }
    end
  end
  # rubocop:enable Metrics/ClassLength
end
