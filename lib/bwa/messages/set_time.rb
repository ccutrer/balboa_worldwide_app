module BWA
  module Messages
    class SetTime < Message
      MESSAGE_TYPE = "\x0a\xbf\x21".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 2

      attr_accessor :hour, :minute, :twenty_four_hour_time

      def initialize(hour = nil, minute = nil, twenty_four_hour_time = nil)
        self.hour, self.minute, self.twenty_four_hour_time = hour, minute, twenty_four_hour_time
      end

      def parse(data)
        self.hour = data[0].ord & 0x7f
        self.minute = data[1].ord
        self.twenty_four_hour_time = !!(data[0].ord & 0x80)
      end

      def serialize
        hour_encoded = hour
        hour_encoded |= 0x80 if twenty_four_hour_time
        super("#{hour_encoded.chr}#{minute.chr}")
      end

      def inspect
        "#<BWA::Messages::SetTime #{Status.format_time(hour, minute, twenty_four_hour_time)}>"
      end
    end
  end
end
