# frozen_string_literal: true

module Warren
  module Exceptions
    # raise {Warren::Exceptions::TemporaryIssue} in a {Warren::Subscriber} to
    # nack the message, requeuing it, and sending the consumers into sleep
    # mode until the issue resolves itself.
    TemporaryIssue = Class.new(StandardError)
  end
end
