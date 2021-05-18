# frozen_string_literal: true

module Warren
  # Namespace for Warren message wrappers.
  module Message
    # A simple message simply wraps the routing key and payload together
    Simple = Struct.new(:routing_key, :payload, :headers)
  end
end
