# frozen_string_literal: true

module BWA
  module Messages
    module Audio
      # The music system's source and playback, sent about once a second while playing.
      class Playback < Message
        MESSAGE_TYPE = "\xbf\xb0".b
        MESSAGE_LENGTH = (9..16)
        SOURCES = { 0 => :line, 1 => :bluetooth }.freeze
        STATES = { 0 => :playing, 1 => :paused, 2 => :stopped }.freeze
        REPEAT_MODES = { 0 => :off, 1 => :one, 2 => :all }.freeze

        # position and duration are in seconds. The state flickers to paused
        # for a moment while playing; BWA::Audio works out what is going on.
        attr_accessor :source, :state, :position, :duration, :repeat, :shuffle
        alias_method :shuffle?, :shuffle

        def log?
          BWA.verbosity >= 1
        end

        def parse(data)
          self.source = SOURCES[data[0].ord]
          self.state = STATES[data[2].ord]
          self.position = data[3, 2].unpack1("n")
          self.duration = data[5, 2].unpack1("n")
          self.repeat = REPEAT_MODES[data[7].ord]
          self.shuffle = data[8].ord != 0
        end

        def inspect
          "#<#{self.class.name} #{source} #{state} " \
            "#{self.class.format_seconds(position)}/#{self.class.format_seconds(duration)} " \
            "repeat=#{repeat} shuffle=#{shuffle}>"
        end

        def self.format_seconds(seconds)
          format("%d:%02d", seconds / 60, seconds % 60)
        end
      end
    end
  end
end
