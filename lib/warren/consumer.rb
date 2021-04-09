# frozen_string_literal: true

APP_PATH = File.expand_path('../config/application', __dir__)

require 'bunny'
require 'warren/postman'
require 'warren/subscription'

# Sets up a pool of workers to process the rebroadcast queues
# This class handles the extraction of command-line parameters
# and their passing to the {WorkerPool}
# @example Basic usage
# `bundle exec bin/amqp_client start`
class AmqpClient
  # Spawns and daemonizes multiple postmen.
  class WorkerPool
    #
    # Create a {Postman} work pool. Typically these are built through the
    # {AmqpClient} and run in daemonized processes.
    # @param app_name [String] The name of the application. Corresponds to the
    #                          subscriptions config in `config/warren.yml`
    # @param workers [Integer] Number of workers to spawn on daemonization
    # @param instance [nil,Integer] Index of the particular worker to start/stop [Optional]
    # @param config [Hash] A configuration object, loaded from `config/warren.yml` by default
    #
    # @return [type] [description]
    def initialize(app_name, workers, instance, config)
      @app_name = app_name
      @worker_count = workers
      @instance = instance
      @config = config
    end

    #
    # Number of workers to spawn on daemonization
    #
    # @return [Integer] Number of workers that will be spawned
    def worker_count
      @instance ? 1 : @worker_count
    end

    #
    # Spawn `worker_count` daemonized workers
    def start!
      worker_count.times do |i|
        daemon(@instance || i)
      end
    end

    # We preload our application before forking!
    def load_rails!
      $stdout.puts 'Loading application...'
      require './config/environment'
      Warren.load_configuration
      # We need to disconnect before forking.
      $stdout.puts 'Registering queues'
      # register_deadletters_queues
      ActiveRecord::Base.connection.disconnect!
      $stdout.puts 'Loaded!'
    end

    #
    # Spawn a new postman in the current process
    # Usually generated automatically in separate daemonized processes via {#start!}
    #
    # @return [Void] Blocking. Will not return until the {Postman} is terminated
    def spawn_postman
      Warren.handler.with_channel do |channel|
        subscription = Warren::Subscription.new(channel: channel, config: queue_config)
        Postman.new(name: @app_name, subscription: subscription).run!
      end
    end

    #
    # Ensures the deadletter queues and exchanges are registered.
    #
    # @return [Void]
    def register_deadletters_queues
      subscription = Warren::Subscription.new(handler: Warren.handler, config: queue_config('.deadletters'))
      client.start
      subscription.activate!
      client.stop
    end

    private

    #
    # Spawn a daemonized {Postman} of index `instance`
    # @param instance [String] The worker we are spawning
    #
    # @return [Void]
    def daemon(_instance)
      # Daemons.run_proc(server_name(instance), multiple: multiple, dir: @pid_dir, backtrace: true, log_output: true) do
      #   ActiveRecord::Base.establish_connection # We reconnect to the database after the fork.
      spawn_postman
      # end
    end

    # Returns true unless we are spawning a specific instance
    def multiple
      @instance.nil?
    end

    def queue_config(config_suffix = nil)
      @config.consumer("#{@app_name}#{config_suffix}")
    end

    #
    # Generates a process name
    # @param i [Integer] Worker index to generate a name for
    #
    # @return [String] Name for the worker
    def server_name(worker_index)
      "#{@app_name}_num#{worker_index}"
    end
  end

  attr_reader :workers, :instance, :config

  def initialize(config, consumers: nil)
    @action = 'start'
    @config = config
    @workers = 1
    @instance = 1
    @consumers = consumers
  end

  def worker_pool
    @worker_pool ||= WorkerPool.new(@consumers.first, worker_count, instance, config)
  end

  def run
    worker_pool.load_rails! if preload_required?
    worker_pool.start!
  end

  # Only bother loading rails if necessary
  def preload_required?
    %w[start restart reload run].include?(@action)
  end

  # If we're not daemonising we limit ourselves to one worker.
  # Otherwise we end up running our various workers in series
  # which isn't really what we want.
  def worker_count
    @action == 'run' ? 1 : workers
  end
end
