# frozen_string_literal: true

module Warren
  module Message
    # Light-weight interim message which can be expanded to a full payload later.
    class Short
      begin
        include AfterCommitEverywhere
      rescue NameError
        # After commit everywhere is not included in the gemfile.
      end

      attr_reader :record

      #
      # Create a 'short' message, where the payload is just the class name and id.
      # Designed for when you wish to use a delayed broadcast.
      #
      # @param record [ActiveRecord::Base] An Active Record object
      #
      def initialize(record = nil, class_name: nil, id: nil)
        if record
          @class_name = record.class.name
          @id = record.id
        else
          @class_name = class_name
          @id = id
        end
      end

      # Queues the message for broadcast at the end of the transaction. Actually want to make this the default
      # behaviour, but only realised the need when doing some last minute integration tests. Will revisit this
      # in the next version. (Or possibly post code review depending)
      def queue(warren)
        after_commit { warren << self }
      rescue NoMethodError
        raise StandardError, '#queue depends on the after_commit_everywhere gem. Please add this to your gemfile'
      end

      # The routing key for the message.
      #
      # @return [String] The routing key
      #
      def routing_key
        "queue_broadcast.#{@class_name.underscore}.#{@id}"
      end

      #
      # The contents of the message, a string in the form:
      # ["<ClassName>",<id>]
      #
      # @return [String] The payload of the message
      #
      def payload
        [@class_name, @id].to_json
      end

      #
      # For compatibility. Returns an empty hash.
      #
      # @return [{}] Empty hash
      def headers
        {}
      end
    end
  end
end
