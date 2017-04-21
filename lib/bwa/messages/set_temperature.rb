module BWA
  module Messages
    class SetTemperature < Message
      MESSAGE_TYPE = "\x0a\xbf\x20".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 1

      attr_accessor :temperature

      def initialize(temperature = nil)
        self.temperature = temperature
      end

      def parse(data)
        self.temperature = data[0].ord
      end

      def serialize
        super(temperature.chr)
      end

      def inspect
        "#<BWA::Messages::SetTemperature #{temperature}º>"
      end
    end
  end
end
