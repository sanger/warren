# frozen_string_literal: true

module Warren
  module Message
    # Generates a payload of an active_record object
    class Full
      attr_reader :record

      def initialize(record)
        @record = record
      end

      #
      # The routing key that will be used for the message, not including the
      # routing_key_prefix configured in warren.yml. If {#record} responds
      # to `routing_key` will use that instead
      #
      # @return [String] The routing key.
      #
      def routing_key
        if record.respond_to?(:routing_key)
          record.routing_key
        else
          "saved.#{record.class.name.underscore}.#{record.id}"
        end
      end

      #
      # The payload of the message.
      # @see https://github.com/intridea/multi_json
      #
      # @return [String] The message payload
      def payload
        MultiJson.dump(record)
      end

      #
      # For compatibility. Returns an empty hash.
      #
      # @return [{}] Empty hash
      def headers
        {}
      end
    end
  end
end
