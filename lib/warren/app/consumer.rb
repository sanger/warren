# frozen_string_literal: true

require 'thor'
require_relative 'consumer_add'
module Warren
  module App
    # Warren Thor CLI subcommand used to:
    # - Add new consumer configurations
    # - Start consumers
    # @see http://whatisthor.com
    class Consumer < Thor
      # Ensure we exit with an error in the event of failure
      def self.exit_on_failure?
        true
      end

      desc 'add NAME', 'generate a new warren consumer'
      option :desc, type: :string,
                    desc: 'Brief description of consumer'
      option :queue, type: :string,
                     desc: 'The RabbitMQ queue to create / connect to'
      option :bindings, type: :array,
                        desc: 'bindings between the queue and exchange',
                        banner: '{direct|fanout|topic|headers}:EXCHANGE[:ROUTING_KEY_A[,ROUTING_KEY_B]]'
      option :path, type: :string,
                    default: 'config/warren_consumers.yml',
                    desc: 'The path to the configuration file to generate'
      def add(name = nil)
        say 'Adding a consumer'
        Warren::App::ConsumerAdd.invoke(shell, name, options)
      end

      desc 'start', 'start registered consumers'
      def start
        say 'starting a consumer'
      end
    end
  end
end
