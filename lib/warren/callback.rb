# frozen_string_literal: true

require_relative 'message/full'
require_relative 'callback/broadcast_with_warren'
require_relative 'callback/broadcast_associated_with_warren'

module Warren
  #
  # Module Warren::Callback provides methods to assist with
  # setting up message broadcast
  #
  module Callback
    # Provides the broadcast_with_warren and broadcasts_associated_with_warren to
    # ActiveRecord::Base classes to configure broadcast
    module ClassMethods
      attr_reader :associated_to_broadcast, :warren

      #
      # Records of this type are broadcast via RabbitMQ when a transaction is closed.
      #
      # @return [void]
      #
      def broadcast_with_warren(handler: Warren.handler)
        after_commit BroadcastWithWarren.new(handler: handler)
      end

      #
      # When records of this type are saved, broadcast the associated records once
      # the transaction is closed. (Requires that associated record is broadcast_with_warren)
      #
      # @param [Symbol,Array<Symbol>] associated One or more symbols indicating the associations to broadcast.
      #
      # @return [void]
      #
      def broadcasts_associated_with_warren(*associated, handler: Warren.handler)
        after_save BroadcastAssociatedWithWarren.new(associated, handler: handler)
      end
    end

    def self.included(base)
      base.class_eval do
        extend ClassMethods
      end
    end

    def broadcast
      # This results in borrowing a connection from the pool
      # per-message. Which isn't ideal. Ideally we'd either
      # check out a connection per thread or per transaction.
      # Any checked out connections will need to be checked back
      # in once the thread/transaction ends with high reliability.
      # So we're doing things the easy way until:
      # 1) Performance requires something more complicated
      # 2) We find a way to achieve the above without monkey-patching
      #    or other complexity (Its probably possible)
      Warren.handler << Warren::Message::Full.new(self)
    end
  end
end
