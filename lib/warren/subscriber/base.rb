# frozen_string_literal: true

require 'logger'
require 'warren/exceptions'

module Warren
  module Subscriber
    # A message takes a rabbitMQ message, and handles its acknowledgement
    # or rejection.
    class Base
      extend Forwardable

      attr_reader :delivery_info, :metadata, :payload, :postman

      # We don't add an active-support dependency, so instead use the plain-ruby
      # delegators (Supplied by Forwardable)
      # Essentially syntax is:
      # def_delegators <target>, *<methods_to_delegate>
      def_delegators :logger, :warn, :info, :error, :debug
      def_delegators :postman, :subscription

      def logger
        @logger ||= if defined?(Rails)
                      Rails.logger
                    else
                      Logger.new($stdout)
                    end
      end

      def initialize(postman, delivery_info, metadata, payload)
        @postman = postman
        @delivery_info = delivery_info
        @metadata = metadata
        @payload = payload
      end

      def _process_
        debug 'Started message process'
        debug payload
        handle_exceptions { process }
        ack
      rescue Warren::Exceptions::TemporaryIssue => e
        temporary_issue(e)
      rescue StandardError => e
        dead_letter(e)
      ensure
        debug 'Finished message process'
      end

      def process
        true
      end

      def handle_exceptions
        yield
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
        subscription.ack(delivery_tag)
      end

      # Reject the message and re-queue ready for
      # immediate reprocessing.
      def requeue(exception)
        warn "Re-queue: #{payload}"
        warn "Re-queue Exception: #{exception.message}"
        subscription.nack(delivery_tag, false, true)
        warn 'Re-queue nacked'
      end

      def temporary_issue(exception)
        # We have some temporary database issues. Requeue the message and pause
        # until the issue is resolved.
        requeue(exception)
        postman.pause!
      end

      # Reject the message without re-queuing
      # Will end up getting dead-lettered
      def dead_letter(exception)
        error "Dead-letter: #{payload}"
        error "Dead-letter Exception: #{exception.message}"
        subscription.nack(delivery_tag)
        error 'Dead-letter nacked'
      end
    end
  end
end
