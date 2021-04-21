# frozen_string_literal: true

require 'logger'
require 'warren/exceptions'

module Warren
  module Subscriber
    # A message takes a rabbitMQ message, and handles its acknowledgement
    # or rejection.
    class Base
      extend Forwardable

      # @return [Warren::Fox] The fox consumer that provided the message. Used to acknowledge messages
      attr_reader :fox
      # @return [Bunny::DeliveryInfo] Contains the information necessary for acknowledging the message
      attr_reader :delivery_info
      # @return [Bunny::MessageProperties] Contains additional information about the received message
      attr_reader :properties
      # @return [String] The message contents
      attr_reader :payload

      # We don't add an active-support dependency, so instead use the plain-ruby
      # delegators (Supplied by Forwardable)
      # Essentially syntax is:
      # def_delegators <target>, *<methods_to_delegate>
      def_delegators :fox, :subscription, :warn, :info, :error, :debug

      #
      # Construct a basic subscriber for each received message. Call {#process}
      # to handle to processing of the message
      #
      # @param fox [Warren::Fox] The fox consumer that provided the message. Used to acknowledge messages
      # @param delivery_info [Bunny::DeliveryInfo] Contains the information necessary for acknowledging the message
      # @param properties [Bunny::MessageProperties] Contains additional information about the received message
      # @param payload [String] The message contents
      #
      def initialize(fox, delivery_info, properties, payload)
        @fox = fox
        @delivery_info = delivery_info
        @properties = properties
        @payload = payload
        @acknowledged = false
      end

      # Called by {Warren::Fox} to trigger processing of the message and acknowledgment
      # on success. In most cases the {#process} method should be used to customize behaviour.
      #
      # @return [Void]
      def _process_
        process
        ack unless @acknowledged
      end

      # Triggers processing of the method. Over-ride this in subclasses to customize your
      # handler.
      def process
        true
      end

      # Reject the message and re-queue ready for
      # immediate reprocessing.
      #
      # @param exception [StandardError] The exception which triggered message requeue
      #
      # @return [Void]
      #
      def requeue(exception)
        warn "Re-queue: #{payload}"
        warn "Re-queue Exception: #{exception.message}"
        raise_if_acknowledged
        subscription.nack(delivery_tag, false, true)
        @acknowledged = true
        warn 'Re-queue nacked'
      end

      # Reject the message without re-queuing
      # Will end up getting dead-lettered
      #
      # @param exception [StandardError] The exception which triggered message dead-letter
      #
      # @return [Void]
      #
      def dead_letter(exception)
        error "Dead-letter: #{payload}"
        error "Dead-letter Exception: #{exception.message}"
        raise_if_acknowledged
        subscription.nack(delivery_tag)
        @acknowledged = true
        error 'Dead-letter nacked'
      end

      private

      def headers
        # Annoyingly it appears that a message with no headers
        # returns nil, not an empty hash
        properties.headers || {}
      end

      def delivery_tag
        delivery_info.delivery_tag
      end

      # Acknowledge the message as successfully processed.
      # Will raise {Warren::MultipleAcknowledgements} if the message has been
      # acknowledged or rejected already.
      def ack
        raise_if_acknowledged
        subscription.ack(delivery_tag)
        @acknowledged = true
      end

      def raise_if_acknowledged
        return unless @acknowledged

        message = "Multiple acks/nacks for: #{payload}"
        error message
        raise Warren::Exceptions::MultipleAcknowledgements, message
      end
    end
  end
end
