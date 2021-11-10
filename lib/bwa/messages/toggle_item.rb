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
                      when 0x04; :pump1
                      when 0x05; :pump2
                      when 0x0c; :blower
                      when 0x0e; :mister
                      when 0x11; :light1
                      when 0x3c; :hold
                      when 0x50; :temperature_range
                      when 0x51; :heating_mode
                      else; data[0].ord
                    end
      end

      def serialize
        data = "\x00\x00"
        if item.is_a? Integer
          data[0] = item.chr
        else
          data[0] = (case item
                      when :pump1; 0x04
                      when :pump2; 0x05
                      when :blower; 0x0c
                      when :mister; 0x0e
                      when :light1; 0x11
                      when :hold; 0x3c
                      when :temperature_range; 0x50
                      when :heating_mode; 0x51
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
