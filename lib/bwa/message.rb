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
        offset = -1
        message_type = length = message_class = nil
        loop do
          offset += 1
          return nil if data.length - offset < 5

          next unless data[offset] == '~'
          length = data[offset + 1].ord
          # impossible message
          next if length < 5

          # don't have enough data for what this message wants;
          # it could be garbage on the line so keep scanning
          next if length + 2 > data.length - offset

          next unless data[offset + length + 1] == '~'

          next unless CRC.checksum(data.slice(offset + 1, length - 1)) == data[offset + length].ord
          break
        end

        puts "discarding invalid data prior to message #{data[0...offset].unpack('H*').first}" unless offset == 0
        #puts "read #{data.slice(offset, length + 2).unpack('H*').first}"

        message_type = data.slice(offset + 2, 3)
        klass = @messages.find { |k| k::MESSAGE_TYPE == message_type }


        return [nil, offset + length + 2] if [
                      "\xfe\xbf\x00".force_encoding(Encoding::ASCII_8BIT),
                      "\x10\xbf\xe1".force_encoding(Encoding::ASCII_8BIT),
                      "\x10\xbf\x07".force_encoding(Encoding::ASCII_8BIT)].include?(message_type)

        raise InvalidMessage.new("Unrecognized message #{message_type.unpack("H*").first}", data) unless klass
        raise InvalidMessage.new("Unrecognized data length (#{length}) for message #{klass}", data) unless length - 5 == klass::MESSAGE_LENGTH

        message = klass.new
        message.parse(data.slice(offset + 5, length - 5))
        message.instance_variable_set(:@raw_data, data.slice(offset, length + 2))
        [message, offset + length + 2]
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
require 'bwa/messages/ready'
require 'bwa/messages/set_temperature'
require 'bwa/messages/set_temperature_scale'
require 'bwa/messages/set_time'
require 'bwa/messages/status'
require 'bwa/messages/toggle_item'
