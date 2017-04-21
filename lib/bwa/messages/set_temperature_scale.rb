module BWA
  module Messages
    class SetTemperatureScale < Message
      MESSAGE_TYPE = "\x0a\xbf\x27".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 2

      attr_accessor :scale

      def initialize(scale = nil)
        self.scale = scale
      end

      def parse(data)
        self.scale = data[1].ord == 0x00 ? :fahrenheit : :celsius
      end

      def serialize
        data = "\x01\x00"
        data[1] = (scale == :fahrenheit ? 0x00 : 0x01).chr
        super(data)
      end

      def inspect
        "#<BWA::Messages::SetTemperatureScale º#{scale.to_s[0].upcase}>"
      end
    end
  end
end
