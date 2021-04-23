# frozen_string_literal: true

module Warren
  module App
    # Handles the initial creation of the configuration object
    class Config
      # We keep the template as plain text as it allows us to add comments
      TEMPLATE = <<~TEMPLATE
        # By default the development environment just logs the message and
        # payload. If you wish to enable broadcasting in development mode,
        # the easiest way to do so is to set the ENV WARREN_TYPE.
        # For example
        # `WARREN_TYPE=broadcast bundle exec rails s`
        # This will override the setting in warren.yml
        development:
          type: log
          # Log mode does not actually use this configuration, but
          # it is provided for convenience when broadcast mode is enabled.
          # The provided settings are the default options of RabbitMQ
          # DO NOT commit sensitive information in this file. Instead you may
          # use the WARREN_CONNECTION_URI environmental variable
          config:
            server:
              host: localhost
              port: 5672
              username: guest
              password: guest
              vhost: %<vhost>s
              frame_max: 0
              heartbeat: 30
            exchange: %<exchange>s
            routing_key_prefix: development
        # The test environment sets up a test message handler, which lets
        # you make assertions about which messages have been sent.
        # See: https://rubydoc.info/gems/sanger_warren/Warren/Handler/Test
        test:
          type: test
          config:
            routing_key_prefix: test
        # You are encouraged to use the WARREN_CONNECTION_URI environmental
        # variable to configure your production environment. Under no
        # circumstances should you commit sensitive information in the file.
      TEMPLATE

      def self.invoke(shell, path:, exchange: nil)
        new(shell, path: path, exchange: exchange).invoke
      end

      #
      # Generates a new warren.yml file at {#path}. Usually invoked via the
      # `warren config` cli command
      #
      # @param shell [Thor::Shell::Basic] Thor shell instance for user interaction
      # @param path [String] The path to the warren.yml file.
      # @param exchange [String] The exchange to connect to
      #
      def initialize(shell, path:, exchange: nil)
        @shell = shell
        @path = path
        @exchange = exchange
      end

      #
      # Create a new configuration yaml file at {#path} using sensible defaults
      # and the provided {#exchange}. If {#exchange} is nil, prompts the user
      #
      # @return [Void]
      #
      def invoke
        return unless check_file?

        @exchange ||= ask_exchange # Update our exchange before we do anything
        File.open(@path, 'w') do |file|
          file.write payload
        end
      end

      private

      # The path to the config file
      attr_reader :path
      # The exchange to connect to
      attr_reader :exchange

      def payload
        format(TEMPLATE, exchange: @exchange, vhost: '/')
      end

      def check_file?
        return true unless File.exist?(@path)

        @shell.yes? "#{@path} exists. Overwrite (Y/N)? "
      end

      def ask_exchange
        @shell.ask 'Specify an exchange: '
      end
    end
  end
end
