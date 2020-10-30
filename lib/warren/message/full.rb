# frozen_string_literal: true

module Warren
  module Message
    # Generates a payload of an active_record object
    class Full
      attr_reader :record

      def initialize(record)
        @record = record
      end

      def routing_key
        if record.respond_to?(:routing_key)
          record.routing_key
        else
          "saved.#{record.class.name.underscore}.#{record.id}"
        end
      end

      def payload
        MultiJson.dump(record)
      end
    end
  end
end
