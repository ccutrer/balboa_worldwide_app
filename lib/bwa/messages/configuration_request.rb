module BWA
  module Messages
    class ConfigurationRequest < Message
      MESSAGE_TYPE = "\x0a\xbf\x04".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 0

      def inspect
        "#<BWA::Messages::ConfigurationRequest>"
      end
    end
  end
end
