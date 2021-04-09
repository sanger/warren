# frozen_string_literal: true

require_relative 'exchange_config'
require 'warren/consumer'

module Warren
  module App
    # Handles the initial creation of the configuration object
    class ConsumerStart
      def self.invoke(shell, options)
        new(shell, options).invoke
      end

      def initialize(shell, options)
        @shell = shell
        @config = Warren::Config::Consumers.new(options[:path])
        @consumers = options[:consumers]
      end

      def invoke
        AmqpClient.new(@config, consumers: @consumers).run
      end
    end
  end
end
