require 'balboa_worldwide_app/crc'

module BalboaWorldwideApp
  class InvalidMessage < RuntimeError
    attr_reader :raw_data

    def initialize(message, data)
      @raw_data = data
      super(message)
    end
  end

  class Message
    class << self
      def inherited(klass)
        @messages ||= []
        @messages << klass
      end

      def from_data(data)
        raise InvalidMessage.new("Malformed data", data) unless data[0] == '~' && data[-1] == '~'
        data_length = data[1].ord
        raise InvalidMessage.new("Incorrect data length (received #{data.length - 2}, expected #{data_length})", data) unless data.length - 2 == data_length
        raise InvalidMessage.new("Missing trailing message indicator", data) unless data[data_length + 1] == '~'
        raise InvalidMessage.new("Invalid checksum", data) unless CRC.checksum(data[1...-2]) == data[-2].ord

        message_type = data[2..4]
        klass = @messages.find { |k| k::MESSAGE_TYPE == message_type }
        raise InvalidMessage.new("Unrecognized message", data) unless klass
        raise InvalidMessage.new("Unrecognized data length (#{data.length - 2})", data) unless data_length == klass::MESSAGE_LENGTH

        message = klass.new(data[5..-3])
        message.instance_variable_set(:@raw_data, data)
        message
      end

      def format_time(hour, minute, twenty_four_hour_time = true)
        if twenty_four_hour_time
          print_hour = "%02d" % hour
        else
          print_hour = hour % 12
          print_hour = 12 if print_hour == 0
          am_pm = (hour >= 12 ? "PM" : "AM")
        end
        "#{print_hour}:#{"%02d" % minute}#{am_pm}"
      end

      def format_duration(hours, minutes)
        "#{hours}:#{"%02d" % minutes}"
      end
    end

    attr_reader :raw_data

    class Configuration < Message
      MESSAGE_TYPE = "\x0a\xbf\x94".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 30

      def initialize(data)
      end
    end

    class Status < Message
      attr_reader :priming,
                  :heating_mode,
                  :temperature_scale,
                  :twenty_four_hour_time,
                  :heating,
                  :temperature_range,
                  :hour, :minute,
                  :circ_pump,
                  :pump1, :pump2,
                  :light1,
                  :current_temperature, :set_temperature

      MESSAGE_TYPE = "\xff\xaf\x13".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 29

      def initialize(data)
        flags = data[1].ord
        @priming = (flags & 0x01 == 0x01)
        flags = data[5].ord
        @heating_mode = case flags & 0x03
                          when 0x00; :ready
                          when 0x01; :rest
                          when 0x02; :ready_in_rest
                        end
        flags = data[9].ord
        @temperature_scale = (flags & 0x01 == 0x01) ? :celsius : :fahrenheit
        @twenty_four_hour_time = (flags & 0x02 == 0x02)
        flags = data[10].ord
        @heating = (flags & 0x30 != 0)
        @temperature_range = (flags & 0x04 == 0x04) ? :high : :low
        flags = data[11].ord
        @pump1 = flags & 0x03
        @pump2 = (flags / 4) & 0x03
        flags = data[13].ord
        @circ_pump = (flags & 0x02 == 0x02)
        flags = data[14].ord
        @light1 = (flags & 0x03 == 0x03)
        @hour = data[3].ord
        @minute = data[4].ord
        @current_temperature = data[2].ord
        @current_temperature = nil if @current_temperature == 0xff
        @set_temperature = data[20].ord
        if temperature_scale == :celsius
          @current_temperature /= 2.0
          @set_temperature /= 2.0
        end
      end

      def inspect
        result = "#<struct BalboaSpaControl::Message::Status "
        items = []

        items << "priming" if priming
        items << self.class.format_time(hour, minute, twenty_four_hour_time)
        items << "#{current_temperature || '--'}/#{set_temperature}º#{temperature_scale.to_s[0].upcase}"
        items << heating_mode
        items << "heating" if heating
        items << temperature_range
        items << "circ_pump" if circ_pump
        items << "pump1=#{pump1}" unless pump1 == 0
        items << "pump2=#{pump2}" unless pump2 == 0
        items << "light1" if light1

        result << items.join(' ') << ">"
      end
    end

    class FilterCycles < Message
      attr_reader :filter1_hour, :filter1_minute, :filter1_duration_hours, :filter1_duration_minutes,
                  :filter2_enabled,
                  :filter2_hour, :filter2_minute, :filter2_duration_hours, :filter2_duration_minutes

      MESSAGE_TYPE = "\x0a\xbf\x23".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 13

      def initialize(data)
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
        result = "#<struct BalboaSpaControl::Message::FilterCycles "

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
