# frozen_string_literal: true

require_relative 'handler/broadcast'
require_relative 'handler/log'
require_relative 'handler/test'
module Warren
  # A {Warren::Handler} provides an interface for sending messages to either
  # a message queue, a log, or an internal store for testing purposes.
  module Handler
    def self.routing_key_template(prefix)
      prefix ? "#{prefix}.%s" : '%s'
    end
  end
end
