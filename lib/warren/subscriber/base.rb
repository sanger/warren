# frozen_string_literal: true

require 'logger'
require 'warren/exceptions'

module Warren
  module Subscriber
    # A message takes a rabbitMQ message, and handles its acknowledgement
    # or rejection.
    class Base
      extend Forwardable

      attr_reader :delivery_info, :metadata, :payload, :fox

      # We don't add an active-support dependency, so instead use the plain-ruby
      # delegators (Supplied by Forwardable)
      # Essentially syntax is:
      # def_delegators <target>, *<methods_to_delegate>
      def_delegators :fox, :subscription, :warn, :info, :error, :debug

      def initialize(fox, delivery_info, metadata, payload)
        @fox = fox
        @delivery_info = delivery_info
        @metadata = metadata
        @payload = payload
        @acknowledged = false
      end

      def _process_
        handle_exceptions { process }
        ack unless @acknowledged
      end

      def process
        true
      end

      def handle_exceptions
        yield
      end

      # Reject the message and re-queue ready for
      # immediate reprocessing.
      def requeue(exception)
        warn "Re-queue: #{payload}"
        warn "Re-queue Exception: #{exception.message}"
        raise_if_acknowledged
        subscription.nack(delivery_tag, false, true)
        @acknowledged = true
        warn 'Re-queue nacked'
      end

      # def temporary_issue(exception)
      #   # We have some temporary database issues. Requeue the message and pause
      #   # until the issue is resolved.
      #   requeue(exception)
      #   fox.pause!
      # end

      # Reject the message without re-queuing
      # Will end up getting dead-lettered
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
        metadata.headers || {}
      end

      def delivery_tag
        delivery_info.delivery_tag
      end

      def ack
        raise_if_acknowledged
        subscription.ack(delivery_tag)
        @acknowledged = true
      end

      def raise_if_acknowledged
        return unless @acknowledged

        error "Multiple acks/nacks for: #{payload}"
        raise MultipleAcknowledgements
      end
    end
  end
end
