# frozen_string_literal: true

require_relative 'exchange_config'
require 'warren/config/consumers'

module Warren
  module App
    # Handles the initial creation of the configuration object
    class ConsumerAdd
      #
      # Add a consumer to the configuration file located at `options.path`
      # Will prompt the user for input on the `shell` if information not
      # provided upfront
      #
      # @param shell [Thor::Shell::Basic] Thor shell instance for feedback
      # @param name [String] The name of the consumer
      # @param options [Hash] Hash of command line arguments from Thor
      # @option options [String] :desc Short description of consumer (for documentation)
      # @option options [String] :queue Then name of the queue to bind to
      # @option options [Array<String>] :bindings Array of binding in the format
      #                                 '<exchange_type>:<exchange_name>:<outing_key>,<routing_key>'
      #
      # @return [ConsumerAdd] The ConsumerAdd
      #
      def self.invoke(shell, name, options)
        new(shell, name, options).invoke
      end

      # Create a consumer configuration object. Use {#invoke} to gather information and
      # generate the config
      #
      # @param shell [Thor::Shell::Basic] Thor shell instance for feedback
      # @param name [String] The name of the consumer
      # @param options [Hash] Hash of command line arguments from Thor
      # @option options [String] :desc Short description of consumer (for documentation)
      # @option options [String] :queue Then name of the queue to bind to
      # @option options [Array<String>] :bindings Array of binding in the format
      #                                 '<exchange_type>:<exchange_name>:<outing_key>,<routing_key>'
      #
      def initialize(shell, name, options)
        @shell = shell
        @name = name
        @desc = options[:desc]
        @queue = options[:queue]
        @config = Warren::Config::Consumers.new(options[:path])
        @bindings = Warren::App::ExchangeConfig.parse(shell, options[:bindings])
      end

      #
      # Create a new configuration yaml file at `@path` using sensible defaults
      # and the provided exchange. If exchange is nil, prompts the user
      #
      # @return [Void]
      #
      def invoke
        check_name if @name # Check name before we gather facts, as its better to know we
        # might have an issue early.
        gather_facts
        write_configuration
      end

      private

      def check_name
        while @config.consumer_exist?(@name)
          @name = @shell.ask(
            "Consumer named '#{@name}' already exists. Specify a alternative " \
            'consumer name: '
          )
        end
      end

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

      def gather_facts
        @name ||= @shell.ask 'Specify a consumer name: '
        check_name
        @desc ||= @shell.ask 'Provide an optional description: '
        @queue ||= @shell.ask 'Provide the name of the queue to connect to: '
        @bindings ||= gather_bindings
        nil
      end

      def gather_bindings
        Warren::App::ExchangeConfig.ask(@shell)
      end

      def write_configuration
        @config.add_consumer(@name, desc: @desc, queue: @queue, bindings: @bindings)
        @config.save
      end
    end
  end
end
