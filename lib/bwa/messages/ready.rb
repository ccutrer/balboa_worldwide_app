# frozen_string_literal: true

module BWA
  module Messages
    class Ready < Message
      MESSAGE_TYPE = "\xbf\06".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 0

      def inspect
        "#<BWA::Messages::Ready>"
      end
    end
  end
end
