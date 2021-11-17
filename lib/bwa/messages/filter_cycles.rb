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
        if changedItem != nil then
          self.filter1_hour = if changedItem == "filter1hour" then changedValue.to_i else oldValues.filter1_hour end
          self.filter1_minute = if changedItem == "filter1minute" then changedValue.to_i else oldValues.filter1_minute end
          self.filter1_duration_hours = if changedItem == "filter1durationhours" then changedValue.to_i else oldValues.filter1_duration_hours end
          self.filter1_duration_minutes = if changedItem == "filter1durationminutes" then changedValue.to_i else oldValues.filter1_duration_minutes end
          self.filter2_enabled = if changedItem == "filter2enabled" then (changedValue == "true" ? true : false) else oldValues.filter2_enabled end
          self.filter2_hour = if changedItem == "filter2hour" then changedValue.to_i else oldValues.filter2_hour end
          self.filter2_minute = if changedItem == "filter2minute" then changedValue.to_i else oldValues.filter2_minute end
          self.filter2_duration_hours = if changedItem == "filter2durationhours" then changedValue.to_i else oldValues.filter2_duration_hours end
          self.filter2_duration_minutes = if changedItem == "filter2durationminutes" then changedValue.to_i else oldValues.filter2_duration_minutes end
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
        data = self.filter1_hour.chr 
        data += self.filter1_minute.chr
        data += self.filter1_duration_hours.chr 
        data += self.filter1_duration_minutes.chr

        #The filter2 start hour is merged with the filter2 enable (who thought that was a good idea?) The high order bit of the byte is a flag
        #to indicate this so we have to do a bit of different processing to set that.
        #Get the filter 2 start hour
        starthour =  self.filter2_hour 

        #Check to see if we want filter 2 enabled (either because it changed or from the current configuration)
        starthour |=  0x80 if self.filter2_enabled

        data += starthour.chr

        data += self.filter2_minute.chr
        data += self.filter2_duration_hours.chr 
        data += self.filter2_duration_minutes.chr

        super(data)

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
