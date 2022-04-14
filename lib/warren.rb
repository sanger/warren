# frozen_string_literal: true

require 'warren/version'
require 'warren/callback'
require 'warren/handler'
require 'warren/message'
require 'warren/subscriber/base'

# Load railties if rails is available
require 'warren/railtie' if defined?(Rails::Railtie)

#
# Module Warren provides connection pooling for RabbitMQ Connections
#
module Warren
  # Environmental variables
  WARREN_TYPE = 'WARREN_TYPE'

  #
  # Construct a {Warren::Handler::Base} of the type `type`.
  # For Rails apps this is usually handled automatically by the initializer.
  #
  # @param type ['test','log','broadcast'] The type of warren handler to construct
  # @param config [Hash] A configuration hash object
  # @option config [Hash] :server Bunny connection parameters
  #                               http://rubybunny.info/articles/connecting.html#using_a_map_of_parameters
  # @option config [String] :exchange The default exchange to receive published messaged
  # @option config [String] :routing_key_prefix A prefix to apply to all routing keys (Such as the environment)
  #
  # @return [Warren::Handler::Base] Exact class determined by the type passed in
  #
  def self.construct(type: 'UNSPECIFIED', config: {})
    warren_type = ENV.fetch(WARREN_TYPE, type)
    case warren_type
    when 'test' then Warren::Handler::Test.new
    when 'log' then Warren::Handler::Log.new(logger: config.fetch(:logger) { Rails.logger })
    when 'broadcast' then Warren::Handler::Broadcast.new(**config)
    else raise StandardError, "Unknown type warren: #{warren_type}"
    end
  end

  # Constructs a Warren::Handler of the specified type and sets it as the global handler.
  def self.setup(opts, logger: Rails.logger)
    logger.warn 'Recreating Warren handler when one already exists' if handler.present?
    @handler = construct(**opts.symbolize_keys)
  end

  #
  # Returns the global Warren handler
  #
  # @return [Warren::Handler::Base] A warren handler for broadcasting messages
  #
  def self.handler
    @handler
  end

  # When we invoke the warren consumer, we end up loading warren before
  # rails is loaded, so don't invoke the railtie, and don't get a change to do
  # so until after the Rails has initialized, and thus run its ties.
  # I'm sure there is a proper way of handling this, but want to move on for now.
  def self.load_configuration
    config = begin
      Rails.application.config_for(:warren)
    rescue RuntimeError => e
      warn <<~WARN
        🐇 WARREN CONFIGURATION ERROR
        #{e.message}
        Use `warren config` to generate a basic configuration file
      WARN
      exit 1
    end
    Warren.setup(config.deep_symbolize_keys.slice(:type, :config))
  end
end
