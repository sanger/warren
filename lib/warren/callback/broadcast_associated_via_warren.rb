# frozen_string_literal: true

module Warren
  module Callback
    # Warren::Callback::BroadcastViaWarren is a Callback class
    # which is used to handle message broadcast of records associated with
    # ActiveRecord::Base objects on save. Associated records will be queued for
    # broadcast when the transaction is closed.
    # @see https://guides.rubyonrails.org/active_record_callbacks.html#callback-classes
    class BroadcastAssociatedViaWarren
      attr_reader :handler, :associations

      def initialize(associations, handler:)
        @associations = associations
        @handler = handler
      end

      #
      # After save callback: configured via broadcasts_associated_via_warren
      # Adds any associated records to the transaction, ensuring their after commit
      # methods will fire.
      #
      # @return [void]
      #
      def after_save(record)
        associations.each do |association|
          record.send(association).try(:add_to_transaction)
        end
      end
    end
  end
end
