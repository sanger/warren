# frozen_string_literal: true

require 'warren/den'

module Warren
  # Establishes message queue consumers {Warren::Fox} according to the
  # configuration. Usually generated via the {Warren::App::Consumer} and
  # triggered via the command line `warren consumer start`
  class Client
    # The interrupt updates the client state to 'stopping' and the control loop
    # handles the actual shutdown. This is as there are limitations on what may
    # take place during an interrupt. This constant controls the frequency at
    # while the control loop polls its state.
    SECONDS_TO_SLEEP = 3

    extend Warren::Helpers::StateMachine
    extend Forwardable

    states :stopping, :stopped, :paused, :starting, :started, :running

    #
    # Build a new client object based on the configuration in `config` and the
    # requested consumers in `consumers`. If `consumers` is nil, all consumers
    # will be spawned. Consumers are spawned on calling {#run} not at
    # initialization
    #
    # @param config [Warren::Config::Consumers] A consumer configuration object
    # @param consumers [Array<String>] The names of the consumers to spawn, or
    #                                  nil to spawn them all
    #
    def initialize(config, consumers: nil, adaptor: Warren::FrameworkAdaptor::RailsAdaptor.new)
      @config = config
      @consumers = consumers || @config.all_consumers
      @adaptor = adaptor
    end

    def run
      starting!
      @adaptor.load_application
      connect_to_rabbit_mq
      trap_signals
      foxes.each(&:run!)
      started!
      control_loop while alive?
    end

    def stop!
      stopping!
      # This method is called from within an interrupt, where the logger
      # is unavailable
      $stdout.puts 'Stopping consumers'
    end

    def alive?
      !stopped?
    end

    private

    def connect_to_rabbit_mq
      Warren.handler.connect
    end

    # Capture the term signal and set the state to stopping.
    # We can't directly cancel the consumer from here as Bunny
    # uses Mutex locking while checking the state. Ruby forbids this
    # from inside a trap block.
    # INT is triggered by Ctrl-C and we provide a manual override to
    # kill things a little quicker as this will mostly happen in
    # development.
    def trap_signals
      Signal.trap('TERM') { stop! }
      Signal.trap('INT') { manual_stop! }
    end

    def foxes
      @foxes ||= @consumers.map do |consumer|
        # Very soon we'll be doing some other stuff in this block.
        # rubocop:disable Style/SymbolProc
        Den.new(consumer, @config, adaptor: @adaptor).tap do |den|
          den.register_dead_letter_queues
        end.fox
        # rubocop:enable Style/SymbolProc
      end
    end

    # Called in an interrupt. (Ctrl-C)
    def manual_stop!
      exit 1 if stopping?
      stop!
      # This method is called from within an interrupt, where the logger
      # is unavailable
      $stdout.puts 'Press Ctrl-C again to stop immediately.'
    end

    # The control loop. Checks the state of the process every three seconds
    # stopping: cancels the consumers, sets the processes to stopped and breaks the loop
    # stopped: (alive? returns false) terminates the loop.
    # anything else: waits three seconds and tries again
    def control_loop
      if stopping?
        foxes.each(&:stop!)
        stopped!
      else
        # Prompt any sleeping workers to check if they need to recover
        foxes.each(&:attempt_recovery)
        sleep(SECONDS_TO_SLEEP)
      end
    end
  end
end
