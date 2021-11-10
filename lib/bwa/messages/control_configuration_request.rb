module BWA
  module Messages
    class ControlConfigurationRequest < Message
      MESSAGE_TYPE = "\xbf\x22".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 3

      attr_accessor :type

      def initialize(type = 1)
        super()
        self.type = type
      end

      def parse(data)
        self.type = case data
          when "\x02\x00\x00"; 1
          when "\x00\x00\x01"; 2
          when "\x01\x00\x00"; 3
          else 0
        end
      end

      def serialize
        data = case type
          when 1; "\x02\x00\x00"
          when 2; "\x00\x00\x01"
          when 3; "\x01\x00\x00"
        else "\x00\x00\x00"
        end
        super(data)
      end

      def inspect
        "#<BWA::Messages::ControlConfigurationRequest #{type}>"
      end
    end
  end
end
