# frozen_string_literal: true

module Warren
  module Handler
    # Base class
    class Base
      #
      # Provide API compatibility with the RabbitMQ versions
      # Do nothing in this case
      #
      def connect; end

      #
      # Provide API compatibility with the RabbitMQ versions
      # Do nothing in this case
      #
      def disconnect; end
    end
  end
end
