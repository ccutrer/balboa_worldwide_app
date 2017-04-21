module BWA
  module Messages
    class ControlConfigurationRequest < Message
      MESSAGE_TYPE = "\x0a\xbf\x22".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 3

      attr_accessor :type

      def initialize(type = 1)
        self.type = type
      end

      def parse(data)
        self.type = data == "\x02\x00\x00" ? 1 : 2
      end


    end
  end
end
