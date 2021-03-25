# frozen_string_literal: true

require 'thor'
require 'warren/app/config'
require 'pry'

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
      def config
        Warren::App::Config.invoke(shell, path: options['path'], exchange: options['exchange'])
      end
    end
  end
end
