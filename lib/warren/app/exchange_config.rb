# frozen_string_literal: true

module Warren
  module App
    # Generate configuration for the various exchange types
    class ExchangeConfig
      EXCHANGE_PROMPT = <<~TYPE
        Add an exchange binding:
          (d)irect
          (f)anout
          (t)opic
          (h)eaders
          (n)one - Stop adding bindings
      TYPE

      # @return [Array] An array of all binding configurations
      attr_reader :bindings

      #
      # Prompts the user to configure multiple queue bindings and returns
      # the bindings array.
      #
      # @param shell [Thor::Shell::Basic] A thor shell object for user communication
      #
      # @return [Array<Hash>] A configuration array
      #
      def self.ask(shell)
        ExchangeConfig.new(shell).tap(&:gather_bindings).bindings
      end

      #
      # Extracts the binding configuration from the command line parameters
      #
      # @param shell [Array<String>] The binding configuration parameters
      #
      # @return [Array<Hash>] A configuration array
      #
      def self.parse(shell, bindings)
        return if bindings.nil?

        ExchangeConfig.new(shell).tap do |config|
          config.parse(bindings)
        end.bindings
      end

      def initialize(shell)
        @shell = shell
        @bindings = []
      end

      def gather_bindings
        loop do
          case ask_exchange_type
          when 'd' then ask_direct_binding
          when 'f' then ask_fanout_binding
          when 't' then ask_topic_binding
          when 'h' then ask_header_binding
          when 'n' then break
          end
        end
      end

      def parse(bindings)
        bindings.each do |binding|
          add_cli_binding(*binding.split(':'))
        end
      end

      def self.default_dead_letter(name)
        new(nil).add_binding('fanout', name, {})
      end

      def add_binding(type, name, options)
        @bindings << config(type, name, options)
      end

      private

      def ask_exchange_type
        @shell.ask(EXCHANGE_PROMPT, limited_to: %w[d f t h n])
      end

      def ask_exchange
        @shell.ask 'Specify an exchange: '
      end

      # This could do with refactoring, but that probably means extracting each exchange
      # type out into its own class.
      def add_cli_binding(type, name = nil, routing_keys = nil)
        case type.downcase
        when 'direct' then add_binding(type, name, { routing_key: routing_keys })
        when 'fanout' then add_binding(type, name, {})
        when 'topic'
          raise(Thor::Error, "Could not extract routing key from #{binding}") if routing_keys.nil?

          routing_keys.split(',').each { |key| add_binding(type, name, { routing_key: key }) }
        when 'header' then add_binding(type, name, { arguments: {} })
        else
          raise Thor::Error, "Unrecognized exchange type: #{type}"
        end
      end

      def ask_direct_binding
        exchange = ask_exchange
        routing_key_tip
        routing_key = @shell.ask 'Specify a routing_key: '
        add_binding('direct', exchange, { routing_key: routing_key })
      end

      def ask_fanout_binding
        exchange = ask_exchange
        add_binding('fanout', exchange, {})
      end

      def ask_header_binding
        exchange = ask_exchange
        @shell.say 'Please manually configure the arguments parameter in the yaml'
        add_binding('header', exchange, { arguments: {} })
      end

      def ask_topic_binding
        exchange = ask_exchange
        routing_key_tip
        loop do
          routing_key = @shell.ask 'Specify a routing_key [Leave blank to stop adding]: '
          break if routing_key == ''

          add_binding('topic', exchange, { routing_key: routing_key })
        end
      end

      def config(type, name, options)
        {
          'exchange' => { 'name' => name, 'options' => { type: type, durable: true } },
          'options' => options
        }
      end

      def routing_key_tip
        # Suggested cop style of %<routing_key_prefix>s but prefer suggesting the simpler option as it
        # would be all to easy to miss out the 's', resulting in varying behaviour depending on the following
        # character
        # rubocop:disable Style/FormatStringToken
        @shell.say(
          'Tip: Use %{routing_key_prefix} in routing keys to reference the routing_key_prefix specified in warren.yml'
        )
        # rubocop:enable Style/FormatStringToken
      end
    end
  end
end
