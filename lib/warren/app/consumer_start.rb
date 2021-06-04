# frozen_string_literal: true

require_relative 'exchange_config'
require 'warren/client'

module Warren
  module App
    # Handles the initial creation of the configuration object
    class ConsumerStart
      #
      # Starts up a warren client process for the configured consumers.
      #
      # @param shell [Thor::Shell::Basic] Thor shell instance for feedback
      # @param options [Hash] Hash of command line arguments from Thor
      # @option options [String] :path Path to the `warren_consumers.yml `file
      # @option options [Array<String>] :consumers Array of configured consumers to start.
      #                                            Defaults to all consumers
      #
      # @return [Void]
      #
      def self.invoke(shell, options)
        new(shell, options).invoke
      end

      def initialize(shell, options)
        @shell = shell
        @config = Warren::Config::Consumers.new(options[:path])
        @consumers = options[:consumers]
      end

      #
      # Starts up a warren client process for the configured consumers.
      #
      # @return [Void]
      def invoke
        Warren::Client.new(@config, consumers: @consumers).run
      end
    end
  end
end
