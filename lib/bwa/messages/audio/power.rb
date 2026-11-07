# frozen_string_literal: true

module BWA
  module Messages
    module Audio
      # Whether the music system is on.
      class Power < Message
        MESSAGE_TYPE = "\xbf\xb4".b
        MESSAGE_LENGTH = (1..8)

        attr_accessor :on
        alias_method :on?, :on

        def parse(data)
          self.on = data[0].ord != 0
        end

        def inspect
          "#<#{self.class.name} #{on ? "on" : "off"}>"
        end
      end
    end
  end
end
