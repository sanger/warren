# frozen_string_literal: true

module Warren
  # Exceptions used by the warren gem
  module Exceptions
    # raise {Warren::Exceptions::TemporaryIssue} in a {Warren::Subscriber} to
    # nack the message, requeuing it, and sending the consumers into sleep
    # mode until the issue resolves itself.
    TemporaryIssue = Class.new(StandardError)

    # {Warren::Exceptions::Exceptions::MultipleAcknowledgements} is raised if a message
    # is acknowledged, or rejected (nacked) multiple times.
    MultipleAcknowledgements = Class.new(StandardError)
  end
end
