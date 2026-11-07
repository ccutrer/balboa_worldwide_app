# frozen_string_literal: true

module BWA
  module Messages
    module Audio
      # The amplifier's Bluetooth name, and whether a phone is connected to it.
      class Bluetooth < Message
        MESSAGE_TYPE = "\xbf\xb3".b
        MESSAGE_LENGTH = (8..120)

        attr_accessor :connected, :address, :name
        alias_method :connected?, :connected

        def parse(data)
          self.connected = data[0].ord == 1 # 2 is waiting for a device
          self.address = data[1, 6].unpack("C6").map { |b| format("%02x", b) }.join(":")
          self.name = Audio.string(data[8, data[7].ord])
        end

        def inspect
          "#<#{self.class.name} #{name.inspect} #{address}#{" connected" if connected}>"
        end
      end
    end
  end
end
