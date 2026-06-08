# frozen_string_literal: true

module Warren
  # Exceptions used by the warren gem
  module Exceptions
    # Top level error class for Warren exceptions.
    class Error < StandardError; end

    # raise {Warren::Exceptions::TemporaryIssue} in a {Warren::Subscriber} to
    # nack the message, requeuing it, and sending the consumers into sleep
    # mode until the issue resolves itself.
    class TemporaryIssue < Error; end

    # {Warren::Exceptions::MultipleAcknowledgements} is raised if a message
    # is acknowledged, or rejected (nacked) multiple times.
    class MultipleAcknowledgements < Error; end

    # Raised when the Bunny session cannot be started.
    class SessionStartError < Error; end
  end
end
