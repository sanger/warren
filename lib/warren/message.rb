# frozen_string_literal: true

# Namespace to collect message formats
# A Warren compatible message must implement:
# routing_key: returns the routing_key for the message
# payloadL returns the message payload

require_relative 'message/short'
require_relative 'message/full'

# Additionally, if you wish to use the Message with the ActiveRecord
# helpers, then the initialize should take the ActiveRecord::Base object
# as a single argument
module Message
end
