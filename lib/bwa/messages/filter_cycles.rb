# frozen_string_literal: true

module BWA
  module Messages
    class FilterCycles < Message
      attr_accessor :cycle1_start_hour, :cycle1_start_minute, :cycle1_duration,
                    :cycle2_enabled, :cycle2_start_hour, :cycle2_start_minute, :cycle2_duration
      alias_method :cycle2_enabled?, :cycle2_enabled

      MESSAGE_TYPE = (+"\xbf\x23").force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 8

      def parse(data)
        self.cycle1_start_hour = data[0].ord
        self.cycle1_start_minute = data[1].ord
        hours = data[2].ord
        minutes = data[3].ord
        self.cycle1_duration = (hours * 60) + minutes

        c2_hour = data[4].ord
        self.cycle2_enabled = !!(c2_hour & 0x80 == 0x80)
        self.cycle2_start_hour = c2_hour & 0x7f
        self.cycle2_start_minute = data[5].ord
        hours = data[6].ord
        minutes = data[7].ord
        self.cycle2_duration = (hours * 60) + minutes
      end

      def serialize
        data = cycle1_start_hour.chr
        data += cycle1_start_minute.chr
        data += (cycle1_duration / 60).chr
        data += (cycle1_duration % 60).chr

        # The cycle2 start hour is merged with the cycle2 enable.
        # The high order bit of the byte is a flag to indicate this so we have
        #  to do a bit of different processing to set that.
        # Get the filter 2 start hour
        start_hour = cycle2_start_hour

        # Check to see if we want filter 2 enabled (either because it changed or from the current configuration)
        start_hour |= 0x80 if cycle2_enabled

        data += start_hour.chr

        data += cycle2_start_minute.chr
        data += (cycle2_duration / 60).chr
        data += (cycle2_duration % 60).chr

        super(data)
      end

      def inspect
        result = +"#<BWA::Messages::FilterCycles "

        result << "cycle1 "
        result << self.class.format_duration(cycle1_duration)
        result << "@"
        result << self.class.format_time(cycle1_start_hour, cycle1_start_minute)

        result << " cycle2(#{@cycle2_enabled ? "enabled" : "disabled"}) "
        result << self.class.format_duration(cycle2_duration)
        result << "@"
        result << self.class.format_time(cycle2_start_hour, cycle2_start_minute)

        result << ">"
      end
    end
  end
end
