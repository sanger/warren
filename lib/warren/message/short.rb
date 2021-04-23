# frozen_string_literal: true

module Warren
  module Message
    # Light-weight interim message which can be expanded to a full payload later.
    class Short
      attr_reader :record

      #
      # Create a 'short' message, where the payload is just the class name and id.
      # Designed for when you wish to use a delayed broadcast.
      #
      # @param record [ActiveRecord::Base] An Active Record object
      #
      def initialize(record)
        @record = record
      end

      # The routing key for the message.
      #
      # @return [String] The routing key
      #
      def routing_key
        "queue_broadcast.#{record.class.name.underscore}.#{record.id}"
      end

      #
      # The contents of the message, a string in the form:
      # ["<ClassName>",<id>]
      #
      # @return [String] The payload of the message
      #
      def payload
        [record.class.name, record.id].to_json
      end
    end
  end
end
