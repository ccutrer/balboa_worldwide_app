module BWA
  module Messages
    class Status < Message
      attr_accessor :priming,
                    :heating_mode,
                    :temperature_scale,
                    :twenty_four_hour_time,
                    :filter,
                    :heating,
                    :temperature_range,
                    :hour, :minute,
                    :circ_pump,
                    :blower,
                    :pumps,
                    :lights,
                    :mister,
                    :aux,
                    :current_temperature, :set_temperature

      MESSAGE_TYPE = "\xaf\x13".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 24

      def initialize
        @src = 0xff
        self.priming = false
        self.heating_mode = :ready
        @temperature_scale = :fahrenheit
        self.twenty_four_hour_time = false
        self.filter = Array.new(2, false)
        self.heating = false
        self.temperature_range = :high
        self.hour = self.minute = 0
        self.circ_pump = false
        self.pumps = Array.new(6, 0)
        self.lights = Array.new(2, false)
        self.mister = false
        self.aux = Array.new(2, false)
        self.set_temperature = 100
      end

      def parse(data)
        flags = data[1].ord
        self.priming = (flags & 0x01 == 0x01)
        flags = data[5].ord
        self.heating_mode = case flags & 0x03
                              when 0x00; :ready
                              when 0x01; :rest
                              when 0x02; :ready_in_rest
                            end
        flags = data[9].ord
        self.temperature_scale = (flags & 0x01 == 0x01) ? :celsius : :fahrenheit
        self.twenty_four_hour_time = (flags & 0x02 == 0x02)
        filter[0] = (flags & 0x04 != 0)
        filter[1] = (flags & 0x08 != 0)
        flags = data[10].ord
        self.heating = (flags & 0x30 != 0)
        self.temperature_range = (flags & 0x04 == 0x04) ? :high : :low
        flags = data[11].ord
        pumps[0] = flags & 0x03
        pumps[1] = (flags >> 2) & 0x03
        pumps[2] = (flags >> 4) & 0x03
        pumps[3] = (flags >> 6) & 0x03
        flags = data[12].ord
        pumps[4] = flags & 0x03
        pumps[5] = (flags >> 2) & 0x03

        flags = data[13].ord
        self.circ_pump = (flags & 0x02 == 0x02)
        self.blower = (flags & 0x0C == 0x0C)
        flags = data[14].ord
        lights[0] = (flags & 0x03 != 0)
        lights[1] = ((flags >> 2) & 0x03 != 0)
        flags = data[15].ord
        self.mister = (flags & 0x01 == 0x01)
        aux[0] = (flags & 0x08 != 0)
        aux[1] = (flags & 0x10 != 0)
        self.hour = data[3].ord
        self.minute = data[4].ord
        self.current_temperature = data[2].ord
        self.current_temperature = nil if self.current_temperature == 0xff
        self.set_temperature = data[20].ord
        if temperature_scale == :celsius
          self.current_temperature /= 2.0
          self.set_temperature /= 2.0
        end
      end

      def serialize
        data = "\x00" * 24
        data[1] = (priming ? 0x01 : 0x00).chr
        data[5] = (case heating_mode
                     when :ready; 0x00
                     when :rest; 0x01
                     when :ready_in_rest; 0x02
                   end).chr
        flags = 0
        flags |= 0x01 if temperature_scale == :celsius
        flags |= 0x02 if twenty_four_hour_time
        data[9] = flags.chr
        flags = 0
        flags |= 0x30 if heating
        flags |= 0x04 if temperature_range == :high
        data[10] = flags.chr
        flags = 0
        flags |= pump1
        flags |= pump2 * 4
        data[11] = flags.chr
        flags = 0
        flags |= 0x02 if circ_pump
        data[13] = flags.chr
        flags = 0
        flags |= 0x03 if light1
        data[14] = flags.chr
        data[3] = hour.chr
        data[4] = minute.chr
        if temperature_scale == :celsius
          data[2] = (current_temperature ? (current_temperature * 2).to_i : 0xff).chr
          data[20] = (set_temperature * 2).to_i.chr
        else
          data[2] = (current_temperature&.to_i || 0xff).chr
          data[20] = set_temperature.to_i.chr
        end

        super(data)
      end

      def temperature_scale=(value)
        if value != @temperature_scale
          if value == :fahrenheit
            if current_temperature
              self.current_temperature *= 9.0/5
              self.current_temperature += 32
              self.current_temperature = current_temperature.round
            end
            self.set_temperature *= 9.0/5
            self.set_temperature += 32
            self.set_temperature = set_temperature.round
          else
            if current_temperature
              self.current_temperature -= 32
              self.current_temperature *= 5.0/90
              self.current_temperature = (current_temperature * 2).round / 2.0
            end
            self.set_temperature -= 32
            self.set_temperature *= 5.0/9
            self.set_temperature = (set_temperature * 2).round / 2.0
          end
        end
        @temperature_scale = value
      end

      def inspect
        result = "#<BWA::Messages::Status "
        items = []

        items << "priming" if priming
        items << self.class.format_time(hour, minute, twenty_four_hour_time)
        items << "#{current_temperature || '--'}/#{set_temperature}º#{temperature_scale.to_s[0].upcase}"
        items << "filter=#{filter.inspect}"
        items << heating_mode
        items << "heating" if heating
        items << temperature_range
        items << "circ_pump" if circ_pump
        items << "blower" if blower
        items << "pumps=#{pumps.inspect}"
        items << "lights=#{lights.inspect}"
        items << "aux=#{aux.inspect}"
        items << "mister" if mister

        result << items.join(' ') << ">"
      end
    end
  end
end