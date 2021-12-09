# frozen_string_literal: true

module BWA
  module Messages
    class FilterCycles < Message
      attr_accessor :filter1_hour, :filter1_minute, :filter1_duration_hours, :filter1_duration_minutes,
                    :filter2_enabled,
                    :filter2_hour, :filter2_minute, :filter2_duration_hours, :filter2_duration_minutes,
                    :changedItem, :changedValue

      MESSAGE_TYPE = "\xbf\x23".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 8

      def initialize(changedItem = nil, changedValue = nil, oldValues = nil)
        super()
        unless changedItem.nil?
          self.filter1_hour = changedItem == "filter1hour" ? changedValue.to_i : oldValues.filter1_hour
          self.filter1_minute = changedItem == "filter1minute" ? changedValue.to_i : oldValues.filter1_minute
          self.filter1_duration_hours = changedItem == "filter1durationhours" ? changedValue.to_i : oldValues.filter1_duration_hours
          self.filter1_duration_minutes = changedItem == "filter1durationminutes" ? changedValue.to_i : oldValues.filter1_duration_minutes
          self.filter2_enabled = if changedItem == "filter2enabled"
                                   changedValue == "true"
                                 else
                                   oldValues.filter2_enabled
                                 end
          self.filter2_hour = changedItem == "filter2hour" ? changedValue.to_i : oldValues.filter2_hour
          self.filter2_minute = changedItem == "filter2minute" ? changedValue.to_i : oldValues.filter2_minute
          self.filter2_duration_hours = changedItem == "filter2durationhours" ? changedValue.to_i : oldValues.filter2_duration_hours
          self.filter2_duration_minutes = changedItem == "filter2durationminutes" ? changedValue.to_i : oldValues.filter2_duration_minutes
        end
      end

      def parse(data)
        self.filter1_hour = data[0].ord
        self.filter1_minute = data[1].ord
        self.filter1_duration_hours = data[2].ord
        self.filter1_duration_minutes = data[3].ord

        f2_hour = data[4].ord
        self.filter2_enabled = !!(f2_hour & 0x80 == 0x80)
        self.filter2_hour = f2_hour & 0x7f
        self.filter2_minute = data[5].ord
        self.filter2_duration_hours = data[6].ord
        self.filter2_duration_minutes = data[7].ord
      end

      def serialize
        data = filter1_hour.chr
        data += filter1_minute.chr
        data += filter1_duration_hours.chr
        data += filter1_duration_minutes.chr

        # The filter2 start hour is merged with the filter2 enable (who thought that was a good idea?) The high order bit of the byte is a flag
        # to indicate this so we have to do a bit of different processing to set that.
        # Get the filter 2 start hour
        starthour = filter2_hour

        # Check to see if we want filter 2 enabled (either because it changed or from the current configuration)
        starthour |= 0x80 if filter2_enabled

        data += starthour.chr

        data += filter2_minute.chr
        data += filter2_duration_hours.chr
        data += filter2_duration_minutes.chr

        super(data)
      end

      def inspect
        result = "#<BWA::Messages::FilterCycles "

        result << "filter1 "
        result << self.class.format_duration(filter1_duration_hours, filter1_duration_minutes)
        result << "@"
        result << self.class.format_time(filter1_hour, filter1_minute)

        result << " filter2(#{@filter2_enabled ? "enabled" : "disabled"}) "
        result << self.class.format_duration(filter2_duration_hours, filter2_duration_minutes)
        result << "@"
        result << self.class.format_time(filter2_hour, filter2_minute)

        result << ">"
      end
    end
  end
end
