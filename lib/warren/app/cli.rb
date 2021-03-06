# frozen_string_literal: true

require 'thor'
require_relative 'config'
require_relative 'consumer'

module Warren
  module App
    # Warren Thor CLI application used to:
    # - Generate the configuration
    # - Update the configuration with new consumers
    # - Start and stop consumers
    # @see http://whatisthor.com
    class Cli < Thor
      # Ensure we exit with an error in the event of failure
      def self.exit_on_failure?
        true
      end

      desc 'config', 'generate a basic warren config file'
      option :path, type: :string,
                    default: 'config/warren.yml',
                    desc: 'The path to the configuration file to generate'
      option :exchange, type: :string,
                        desc: 'The RabbitMQ exchange to connect to'
      # Invoked by `$ warren config` generates a `warren.yml` file.
      def config
        Warren::App::Config.invoke(self, path: options['path'], exchange: options['exchange'])
      end

      desc 'consumer {add|start}', 'add and start queue consumers'
      subcommand 'consumer', Consumer
    end
  end
end
