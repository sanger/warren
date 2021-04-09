# frozen_string_literal: true

require 'yaml'

module Warren
  module Config
    # Manages the configuration of consumers. By default, consumer configuration
    # is held in {DEFAULT_PATH config/warren_consumers.yml}
    class Consumers
      # Default path to the consumer configuration file
      DEFAULT_PATH = 'config/warren_consumers.yml'
      WRITE_ONLY_TRUNCATE = 'w'

      def initialize(path)
        @path = path
        @config = load_config
      end

      #
      # Save the configuration to {path}
      #
      # @return [Void]
      #
      def save
        File.open(@path, WRITE_ONLY_TRUNCATE) do |file|
          file.write YAML.dump(@config)
        end
      end

      #
      # Checks whether a consumer has already been registered
      #
      # @param name [String] The name of the consumer to check
      #
      # @return [Boolean] True if the consumer exists
      #
      def consumer_exist?(name)
        @config.key?(name)
      end

      def consumer(name)
        @config.fetch(name) { raise StandardError, "Unknown consumer '#{name}'" }
      end

      #
      # Register a new consumer
      #
      # @param name [String] The name of the consumer to register
      # @param desc [String] Description of the consumer (Primarily for documentation)
      # @param queue [String] Name of the queue to attach to
      # @param bindings [Array<Hash>] Array of binding configuration hashed
      #
      # @return [Hash] The consumer configuration hash
      #
      def add_consumer(name, desc:, queue:, bindings:)
        @config[name] = {
          'desc' => desc,
          'queue' => {
            'name' => queue,
            'options' => { durable: true, arguments: { 'x-dead-letter-exchange' => "#{name}.dead-letters" } },
            'bindings' => bindings
          }
        }
      end

      private

      #
      # Loads the configuration, should be a hash
      #
      # @return [Hash] A hash of consumer configurations indexed by name
      #
      def load_config
        YAML.load_file(@path)
      rescue Errno::ENOENT
        {}
      end
    end
  end
end
