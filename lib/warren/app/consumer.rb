# frozen_string_literal: true

require 'thor'
require 'warren/app/config'
require 'pry'

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
      option :name, type: :string,
                    desc: 'The name of the consumer to generate'
      option :desc, type: :string,
                    desc: 'Brief description of consumer'
      option :exchange, type: :string,
                        desc: 'The RabbitMQ exchange to connect to'
      option :queue, type: :string,
                     desc: 'The RabbitMQ queue to create / connect to'
      option :bindings, type: :array,
                        desc: 'bindings between the queue and exchange'
      def add
        say 'Adding a consumer'
      end

      desc 'start', 'start registered consumers'
      def start
        say 'starting a consumer'
      end
    end
  end
end
