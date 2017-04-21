require 'bwa/crc'

module BWA
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

      def parse(data)
        raise InvalidMessage.new("Malformed data", data) unless data[0] == '~' && data[-1] == '~'
        data_length = data[1].ord
        raise InvalidMessage.new("Incorrect data length (received #{data.length - 2}, expected #{data_length})", data) unless data.length - 2 == data_length
        raise InvalidMessage.new("Missing trailing message indicator", data) unless data[data_length + 1] == '~'
        raise InvalidMessage.new("Invalid checksum", data) unless CRC.checksum(data[1...-2]) == data[-2].ord

        message_type = data[2..4]
        klass = @messages.find { |k| k::MESSAGE_TYPE == message_type }
        raise InvalidMessage.new("Unrecognized message #{message_type.unpack("H*").first}", data) unless klass
        raise InvalidMessage.new("Unrecognized data length (#{data_length}) for message #{klass}", data) unless data_length - 5 == klass::MESSAGE_LENGTH

        message = klass.new
        message.parse(data[5..-3])
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

    def parse(_data)
    end

    def serialize(message = "")
      length = message.length + 5
      full_message = "#{length.chr}#{self.class::MESSAGE_TYPE}#{message}".force_encoding(Encoding::ASCII_8BIT)
      checksum = CRC.checksum(full_message)
      "\x7e#{full_message}#{checksum.chr}\x7e".force_encoding(Encoding::ASCII_8BIT)
    end

    def inspect
      "#<#{self.class.name} #{raw_data.unpack("H*").first}>"
    end
  end
end

require 'bwa/messages/configuration'
require 'bwa/messages/configuration_request'
require 'bwa/messages/control_configuration'
require 'bwa/messages/control_configuration_request'
require 'bwa/messages/filter_cycles'
require 'bwa/messages/set_temperature'
require 'bwa/messages/set_temperature_scale'
require 'bwa/messages/set_time'
require 'bwa/messages/status'
require 'bwa/messages/toggle_item'
