# frozen_string_literal: true

module Warren
  module App
    # Handles the initial creation of the configuration object
    class ConsumerAdd
      def self.invoke(shell)
        new(shell).invoke
      end

      def initialize(shell)
        @shell = shell
        gather_facts
      end

      #
      # Create a new configuration yaml file at {#path} using sensible defaults
      # and the provided {#exchange}. If {#exchange} is nil, prompts the user
      #
      # @return [Void]
      #
      def invoke; end

      private

      def gather_facts; end
    end
  end
end
