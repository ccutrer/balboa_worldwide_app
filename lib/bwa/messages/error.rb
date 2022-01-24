# frozen_string_literal: true

module BWA
  module Messages
    class Error < Message
      MESSAGE_TYPE = "\xbf\xe1".b
      MESSAGE_LENGTH = 1

      def log?
        BWA.verbosity >= 1
      end

      def inspect
        "#<BWA::Messages::Error>"
      end
    end
  end
end
