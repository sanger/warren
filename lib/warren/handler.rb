# frozen_string_literal: true

require_relative 'handler/broadcast'
require_relative 'handler/log'
require_relative 'handler/test'
module Warren
  # A {Warren::Handler} provides an interface for sending messages to either
  # a message queue, a log, or an internal store for testing purposes.
  module Handler
    #
    # Generates a template for routing keys for the given prefix, or a template
    # that returns the provided routing key if no prefix is supplied.
    #
    # @example With a prefix
    #   template = Warren::Handler.routing_key_template('example') # => 'example.%s'
    #   format(template, 'routing.key') #=> 'example.routing.key'
    #
    # @example Without a prefix
    #   template = Warren::Handler.routing_key_template(nil) # => '%s'
    #   format(template, 'routing.key') #=> 'routing.key'
    #
    # @param prefix [String, nil] The prefix to use in the template
    #
    # @return [String] A template for generating routing keys
    #
    def self.routing_key_template(prefix)
      prefix ? "#{prefix}.%s" : '%s'
    end
  end
end
