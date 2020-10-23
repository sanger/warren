# frozen_string_literal: true

module Warren
  module Message
    # Light-weight interim message which can be expanded to a full payload later.
    class Short
      attr_reader :record

      def initialize(record)
        @record = record
      end

      def routing_key
        "#{Rails.env}.queue_broadcast.#{record.class.name.underscore}.#{record.id}"
      end

      def payload
        [record.class.name, record.id].to_json
      end
    end
  end
end
