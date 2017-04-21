module BWA
  module Messages
    class FilterCycles < Message
      attr_reader :filter1_hour, :filter1_minute, :filter1_duration_hours, :filter1_duration_minutes,
                  :filter2_enabled,
                  :filter2_hour, :filter2_minute, :filter2_duration_hours, :filter2_duration_minutes

      MESSAGE_TYPE = "\x0a\xbf\x23".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 8

      def parse(data)
        @filter1_hour = data[0].ord
        @filter1_minute = data[1].ord
        @filter1_duration_hours = data[2].ord
        @filter1_duration_minutes = data[3].ord

        f2_hour = data[4].ord
        @filter2_enabled = !!(f2_hour & 0x80 == 0x80)
        @filter2_hour = f2_hour & 0x7f
        @filter2_minute = data[5].ord
        @filter2_duration_hours = data[6].ord
        @filter2_duration_minutes = data[7].ord
      end

      def inspect
        result = "#<BWA::Messages::FilterCycles "

        result << "filter1 "
        result << self.class.format_duration(filter1_duration_hours, filter1_duration_minutes)
        result << "@"
        result << self.class.format_time(filter1_hour, filter1_minute)

        result << " filter2(#{@filter2_enabled ? 'enabled' : 'disabled'}) "
        result << self.class.format_duration(filter2_duration_hours, filter2_duration_minutes)
        result << "@"
        result << self.class.format_time(filter2_hour, filter2_minute)

        result << ">"
      end
    end
  end
end
