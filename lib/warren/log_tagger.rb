# frozen_string_literal: true

module Warren
  # Applies a tag to any messages sent to the logger.
  class LogTagger
    #
    # Create a new log tagger, which applies a tag to all messages before
    # forwarding them on to the logger
    #
    # @param logger [Logger] A ruby Logger, or compatible interface
    # @param tag [String] The tag to apply to each message
    #
    def initialize(logger:, tag:)
      @logger = logger
      @tag = tag
    end

    #
    # Define `name` methods which forward on to the similarly named method
    # on logger, with the tag applied
    #
    # @param name [Symbol] The method to define
    #
    # @return [Void]
    def self.level(name)
      define_method(name) do |arg = nil, &block|
        if block
          @logger.public_send(name, arg) { tag(block.call) }
        else
          @logger.public_send(name, tag(arg))
        end
      end
    end

    # @!method debug(message)
    #   Forwards message on to logger with {#tag} prefix
    #   See Logger::debug
    level :debug
    # @!method info(message)
    #   Forwards message on to logger with {#tag} prefix
    #   See Logger::info
    level :info
    # @!method warn(message)
    #   Forwards message on to logger with {#tag} prefix
    #   See Logger::warn
    level :warn
    # @!method error(message)
    #   Forwards message on to logger with {#tag} prefix
    #   See Logger::error
    level :error

    private

    def tag(message)
      "#{@tag}: #{message}"
    end
  end
end
