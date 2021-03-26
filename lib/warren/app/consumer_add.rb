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

      private

      #
      # Create a new configuration yaml file at {#path} using sensible defaults
      # and the provided {#exchange}. If {#exchange} is nil, prompts the user
      #
      # @return [Void]
      #
      def invoke
        return unless check_file?

        @exchange ||= ask_exchange # Update our exchange before we do anything
        File.open(@path, 'w') do |file|
          file.write payload
        end
      end
    end
  end
end
