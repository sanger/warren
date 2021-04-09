# frozen_string_literal: true

module Warren
  # Namespace for utility modules
  module Helpers
    # Provides an incredibly simple state machine. It merely lets you define
    # states with {#state} which defines two methods `{state}!` to transition
    # into the state and `{state}?` to query if we are in the state.
    #
    # == Usage:
    #
    # @example Basic usage
    #   class Machine
    #     extend Warren::Helpers::StateMachine
    #     states :started, :started
    #   end
    #
    #   machine = Machine.new
    #   machine.started!
    #   machine.started? # => true
    #   machine.stopped? # => false
    #   machine.stopped!
    #   machine.started? # => false
    #   machine.stopped? # => stopped
    #
    module StateMachine
      #
      # Define a new state, generates two methods `{state}!` to transition
      # into the state and `{state}?` to query if we are in the state.
      #
      # @param state_name [Symbol, String] The name of the state
      #
      # @return [Void]
      #
      def state(state_name)
        define_method(:"#{state_name}!") { @state = state_name }
        define_method(:"#{state_name}?") { @state == state_name }
      end

      #
      # Define new states, generates two methods for each state `{state}!` to
      # transition into the state and `{state}?` to query if we are in the state.
      #
      # @overload push2(state_name, ...)
      #   @param [Symbol, String] state_name The name of the state
      #   @param [Symbol, String] ... More states
      #
      # @return [Void]
      #
      def states(*state_names)
        state_names.each { |state_name| state(state_name) }
      end
    end
  end
end
