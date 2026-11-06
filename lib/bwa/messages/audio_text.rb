# frozen_string_literal: true

module BWA
  module Messages
    # One piece of the current song's text: sent when the song changes, and
    # in answer to a request.
    class AudioText < Message
      MESSAGE_TYPE = "\xbf\xb1".b
      MESSAGE_LENGTH = (2..120)
      FIELDS = { 0 => :title, 1 => :album, 2 => :artist }.freeze

      attr_accessor :field, :text

      def parse(data)
        self.field = FIELDS[data[0].ord] || data[0].ord
        self.text = Messages.audio_string(data[2, data[1].ord])
      end

      def inspect
        "#<BWA::Messages::AudioText #{field} #{text.inspect}>"
      end
    end

    # Text from the amplifier: null terminated, and not always valid UTF-8.
    def self.audio_string(data)
      (data || "").dup.force_encoding(Encoding::UTF_8).scrub.delete("\0").strip
    end
  end
end
