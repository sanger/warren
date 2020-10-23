# frozen_string_literal: true

require_relative 'message/full'
require 'connection_pool'
#
# Module Warren::Callback provides methods to assist with
# setting up message broadcast
#
module Warren
  #
  # Module Warren::BroadcastMessages provides methods to assist with
  # setting up message broadcast
  #
  module Callback
    # Provides the broadcast_via_warren and broadcasts_associated_via_warren to
    # ActiveRecord::Base classes to configure broadcast
    module ClassMethods
      attr_reader :associated_to_broadcast, :warren

      #
      # Records of this type are broadcast via RabbitMQ when a transaction is closed.
      #
      # @return [void]
      #
      def broadcast_via_warren(handler: Warren.handler)
        after_commit BroadcastViaWarren.new(handler: handler)
      end

      #
      # When records of this type are saved, broadcast the associated records
      #
      # @param [Symbol,Array<Symbol>] associated One or more symbols indicating the associations to broadcast.
      #
      # @return [void]
      #
      def broadcasts_associated_via_warren(*associated, handler: Warren.handler)
        after_save BroadcastAssociatedViaWarren.new(associated, handler: handler)
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
      warren << Warren::Message::Full.new(self)
    end
  end
end

require_relative 'callback/broadcast_via_warren'
require_relative 'callback/broadcast_associated_via_warren'
