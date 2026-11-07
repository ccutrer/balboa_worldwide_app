# frozen_string_literal: true

module BWA
  module Messages
    module Audio
      # One piece of the current song's text: sent when the song changes, and
      # in answer to a request.
      class Text < Message
        MESSAGE_TYPE = "\xbf\xb1".b
        MESSAGE_LENGTH = (2..120)
        FIELDS = { 0 => :title, 1 => :album, 2 => :artist }.freeze

        attr_accessor :field, :text

        def parse(data)
          self.field = FIELDS[data[0].ord] || data[0].ord
          self.text = Audio.string(data[2, data[1].ord])
        end

        def inspect
          "#<#{self.class.name} #{field} #{text.inspect}>"
        end
      end
    end
  end
end
