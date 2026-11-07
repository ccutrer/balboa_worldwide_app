# frozen_string_literal: true

module BWA
  module Messages
    # Messages to and from the music system (the bba amplifier).
    module Audio
      # Text from the amplifier: null terminated, and not always valid UTF-8.
      def self.string(data)
        (data || "").dup.force_encoding(Encoding::UTF_8).scrub.delete("\0").strip
      end
    end
  end
end

require "bwa/messages/audio/bluetooth"
require "bwa/messages/audio/command"
require "bwa/messages/audio/playback"
require "bwa/messages/audio/power"
require "bwa/messages/audio/text"
require "bwa/messages/audio/volume"
