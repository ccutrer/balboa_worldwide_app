module BWA
  module Messages
    class ToggleItem < Message
      MESSAGE_TYPE = "\xbf\x11".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 2

      attr_accessor :item

      def initialize(item = nil)
        super()
        self.item = item
      end

      def parse(data)
        self.item = case data[0].ord
                    when 0x04 then :pump1
                    when 0x05 then :pump2
                    when 0x0c then :blower
                    when 0x0e then :mister
                    when 0x11 then :light1
                    when 0x3c then :hold
                    when 0x50 then :temperature_range
                    when 0x51 then :heating_mode
                    else; data[0].ord
                    end
      end

      def serialize
        data = "\x00\x00"
        data[0] = if item.is_a? Integer
                    item.chr
                  else
                    (case item
                     when :pump1 then 0x04
                     when :pump2 then 0x05
                     when :blower then 0x0c
                     when :mister then 0x0e
                     when :light1 then 0x11
                     when :hold then 0x3c
                     when :temperature_range then 0x50
                     when :heating_mode then 0x51
                     end).chr
                  end
        super(data)
      end

      def inspect
        "#<BWA::Messages::ToggleItem #{item}>"
      end
    end
  end
end
