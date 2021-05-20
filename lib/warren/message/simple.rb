# frozen_string_literal: true

module Warren
  # Namespace for Warren message wrappers.
  module Message
    # A simple message simply wraps the routing key and payload together
    # @!attribute [rw] routing_key
    #   @return [String] The routing key of the message
    # @!attribute [rw] payload
    #   @return [String] The payload of the message
    # @!attribute [rw] headers
    #   @return [Hash] Hash of header attributes. Can be empty hash.
    Simple = Struct.new(:routing_key, :payload, :headers)
  end
end
