# frozen_string_literal: true

require 'warren/message/short'

module Warren
  module Callback
    # Warren::Callback::BroadcastViaWarren is a Callback class
    # which is used to handle message broadcast of ActiveRecord::Base objects
    # on commit
    # @see https://guides.rubyonrails.org/active_record_callbacks.html#callback-classes
    class BroadcastViaWarren
      attr_reader :handler, :message_class

      def initialize(handler:, message_class: Warren::Message::Short)
        @handler = handler
        @message_class = message_class
      end

      def after_commit(record)
        # Message rendering is slow in some cases. This broadcasts an initial
        # lightweight message which can be picked up and rendered asynchronously
        # Borrows connection as per #broadcast
        handler << message_class.new(record)
      end
    end
  end
end
