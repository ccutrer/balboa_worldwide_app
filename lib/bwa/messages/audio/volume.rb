# frozen_string_literal: true

module BWA
  module Messages
    module Audio
      # The music system's volume. Each source keeps its own.
      class Volume < Message
        MESSAGE_TYPE = "\xbf\xb2".b
        MESSAGE_LENGTH = (7..16)

        attr_accessor :volume, :muted, :max_volume
        alias_method :muted?, :muted

        def parse(data)
          self.volume = data[0].ord
          self.muted = data[3].ord != 0
          self.max_volume = data[6].ord
          self.max_volume = nil if max_volume.zero?
        end

        def inspect
          "#<#{self.class.name} #{volume}/#{max_volume}#{" muted" if muted}>"
        end
      end
    end
  end
end
