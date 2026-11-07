# frozen_string_literal: true

module BWA
  module Messages
    module Audio
      # A command for the music system (the bba amplifier).
      #
      # The panel and the WiFi module send these to the pack, which passes each
      # on to the amplifier with the amplifier's own channel as the source.
      class Command < Message
        MESSAGE_TYPE = "\xbf\xb5".b
        MESSAGE_LENGTH = 2
        COMMANDS = {
          power: 0x00, # 0 off, 1 on
          source: 0x01, # see Playback::SOURCES
          play: 0x02,
          pause: 0x03,
          next: 0x05,
          previous: 0x06,
          volume: 0x09, # the volume to set
          mute: 0x0a, # 0 off, 1 on
          repeat: 0x0d, # see Playback::REPEAT_MODES
          shuffle: 0x0e, # 0 off, 1 on
          request: 0x11 # an index into BWA::Audio::REQUESTS
        }.freeze

        attr_accessor :command, :argument

        def initialize(command = nil, argument = 0)
          super()
          self.command = command
          self.argument = argument
        end

        def parse(data)
          self.command = COMMANDS.key(data[0].ord) || data[0].ord
          self.argument = data[1].ord
        end

        def serialize
          code = command.is_a?(Integer) ? command : COMMANDS.fetch(command)
          super("#{code.chr}#{argument.chr}")
        end

        def inspect
          "#<#{self.class.name} #{command} #{argument}>"
        end
      end
    end
  end
end
