# frozen_string_literal: true

require 'warren/version'
require 'warren/callback'
require 'warren/handler'
require 'warren/message'

#
# Module Warren provides connection pooling for RabbitMQ Connections
#
module Warren
  def self.construct(type:, config: {})
    case type
    when 'test' then Warren::Handler::Test.new
    when 'log' then Warren::Handler::Log.new(logger: config.fetch(:logger) { Rails.logger })
    when 'broadcast' then Warren::Handler::Broadcast.new(config)
    else raise StandardError, "Unknown type warren: #{type}"
    end
  end

  def self.setup(opts, logger: Rails.logger)
    logger.warn 'Recreating Warren handler when one already exists' if handler.present?
    @handler = construct(opts.symbolize_keys)
  end

  def self.handler
    @handler
  end
end
