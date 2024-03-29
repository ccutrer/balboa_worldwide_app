# frozen_string_literal: true

module BWA
  module Messages
    class Ready < Message
      MESSAGE_TYPE = "\xbf\06".b
      MESSAGE_LENGTH = 0

      def log?
        BWA.verbosity >= 2
      end

      def inspect
        "#<BWA::Messages::Ready>"
      end
    end
  end
end
