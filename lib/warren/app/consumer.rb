# frozen_string_literal: true

require 'thor'
require_relative 'consumer_add'
require_relative 'consumer_start'
require 'warren/config/consumers'

module Warren
  module App
    # Warren Thor CLI subcommand used to:
    # - Add new consumer configurations
    # - Start consumers
    # @see http://whatisthor.com
    class Consumer < Thor
      include Thor::Actions

      source_root("#{File.dirname(__FILE__)}/templates")

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
                    default: Warren::Config::Consumers::DEFAULT_PATH,
                    desc: 'The path to the consumer configuration file to generate'
      def add(name = nil)
        say 'Adding a consumer'
        Warren::App::ConsumerAdd.invoke(self, name, options)
      end

      desc 'start', 'start registered consumers'
      option :path, type: :string,
                    default: Warren::Config::Consumers::DEFAULT_PATH,
                    desc: 'The path to the consumer configuration file to use'
      option :consumers, type: :array,
                         desc: 'The consumers to start. Defaults to all consumers',
                         banner: 'consumer_name other_consumer'
      def start
        say 'Starting consumers'
        Warren::App::ConsumerStart.invoke(self, options)
      end
    end
  end
end
