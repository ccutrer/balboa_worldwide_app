# frozen_string_literal: true

module BWA
  module Messages
    class Configuration < Message
      MESSAGE_TYPE = "\xbf\x94".b
      MESSAGE_LENGTH = 25

      def inspect
        "#<BWA::Messages::Configuration>"
      end
    end
  end
end
