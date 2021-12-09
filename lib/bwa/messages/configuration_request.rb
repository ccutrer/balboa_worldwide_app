# frozen_string_literal: true

module BWA
  module Messages
    class ConfigurationRequest < Message
      MESSAGE_TYPE = "\xbf\x04".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 0

      def inspect
        "#<BWA::Messages::ConfigurationRequest>"
      end
    end
  end
end
