# frozen_string_literal: true

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
                    when "\x02\x00\x00" then 1
                    when "\x00\x00\x01" then 2
                    when "\x01\x00\x00" then 3
                    else 0
                    end
      end

      def serialize
        data = case type
               when 1 then "\x02\x00\x00"
               when 2 then "\x00\x00\x01"
               when 3 then "\x01\x00\x00"
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
