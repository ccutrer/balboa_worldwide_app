# frozen_string_literal: true

module BWA
  module Messages
    class NewClientClearToSend < Message
      MESSAGE_TYPE = "\xbf\0".b
      MESSAGE_LENGTH = 0

      def log?
        BWA.verbosity >= 2
      end

      def inspect
        "#<BWA::Messages::NewClientClearToSend>"
      end
    end
  end
end
