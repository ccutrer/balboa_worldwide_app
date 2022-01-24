# frozen_string_literal: true

module BWA
  module Messages
    class NothingToSend < Message
      MESSAGE_TYPE = "\xbf\x07".b
      MESSAGE_LENGTH = 0

      def log?
        BWA.verbosity >= 2
      end

      def inspect
        "#<BWA::Messages::NothingToSend>"
      end
    end
  end
end
