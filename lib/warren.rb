# frozen_string_literal: true

require 'warren/version'
require 'warren/callback'
require 'warren/handler'
require 'warren/message'

# Load railties if rails is available
require 'warren/railtie' if defined?(Rails::Railtie)

#
# Module Warren provides connection pooling for RabbitMQ Connections
#
module Warren
  def self.construct(type:, config: {})
    case type
    when 'test' then Warren::Handler::Test.new
    when 'log' then Warren::Handler::Log.new(logger: config.fetch(:logger) { Rails.logger })
    when 'broadcast' then Warren::Handler::Broadcast.new(**config)
    else raise StandardError, "Unknown type warren: #{type}"
    end
  end

  def self.setup(opts, logger: Rails.logger)
    logger.warn 'Recreating Warren handler when one already exists' if handler.present?
    @handler = construct(**opts.symbolize_keys)
  end

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
