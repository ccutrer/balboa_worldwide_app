# frozen_string_literal: true

module BWA
  module Messages
    class ToggleItem < Message
      MESSAGE_TYPE = "\xbf\x11".b
      MESSAGE_LENGTH = 2
      ITEMS = {
        normal_operation: 0x01,
        clear_notification: 0x03,
        pump1: 0x04,
        pump2: 0x05,
        pump3: 0x06,
        pump4: 0x07,
        pump5: 0x08,
        pump6: 0x09,
        blower: 0x0c,
        mister: 0x0e,
        light1: 0x11,
        light2: 0x12,
        aux1: 0x16,
        aux2: 0x17,
        soak: 0x1d,
        hold: 0x3c,
        temperature_range: 0x50,
        heating_mode: 0x51
      }.freeze

      attr_accessor :item

      def initialize(item = nil)
        super()
        self.item = item
      end

      def log?
        return true if BWA.verbosity >= 2
        # dunno why we receive this, but somebody is spamming the bus
        # trying to toggle an item we don't know
        return false if item == 0 # rubocop:disable Style/NumericPredicate could be a symbol

        true
      end

      def parse(data)
        self.item = ITEMS.invert[data[0].ord] || data[0].ord
      end

      def serialize
        data = +"\x00\x00"
        data[0] = if item.is_a?(Integer)
                    item.chr
                  else
                    ITEMS[item].chr
                  end
        super(data)
      end

      def inspect
        "#<BWA::Messages::ToggleItem #{item}>"
      end
    end
  end
end
