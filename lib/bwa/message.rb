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
    class Unrecognized < Message
    end

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

          # Keep scanning until message start char
          next unless data[offset] == '~'

          # Read length (safe since we have at least 5 chars)
          length = data[offset + 1].ord

          # No message is this short or this long; keep scanning
          next if length < 5 or length >= '~'.ord

          # don't have enough data for what this message wants;
          # return and hope for more (yes this might cause a
          # delay, but the protocol is very chatty so it won't
          # be long)
          return nil if length + 2 > data.length - offset

          # Not properly terminated; keep scanning
          next unless data[offset + length + 1] == '~'

          # Not a valid checksum; keep scanning
          next unless CRC.checksum(data.slice(offset + 1, length - 1)) == data[offset + length].ord

          # Got a valid message!
          break
        end

        puts "discarding invalid data prior to message #{data[0...offset].unpack('H*').first}" unless offset == 0
        #puts "read #{data.slice(offset, length + 2).unpack('H*').first}"

        src = data[offset + 2].ord
        message_type = data.slice(offset + 3, 2)
        klass = @messages.find { |k| k::MESSAGE_TYPE == message_type }


        return [nil, offset + length + 2] if [
                      "\xbf\x00".force_encoding(Encoding::ASCII_8BIT),
                      "\xbf\xe1".force_encoding(Encoding::ASCII_8BIT),
                      "\xbf\x07".force_encoding(Encoding::ASCII_8BIT)].include?(message_type)

        if klass
          valid_length = if klass::MESSAGE_LENGTH.respond_to?(:include?)
            klass::MESSAGE_LENGTH.include?(length - 5)
          else
            length - 5 == klass::MESSAGE_LENGTH
          end
          raise InvalidMessage.new("Unrecognized data length (#{length}) for message #{klass}", data) unless valid_length
        else
          klass = Unrecognized
        end

        message = klass.new
        message.parse(data.slice(offset + 5, length - 5))
        message.instance_variable_set(:@raw_data, data.slice(offset, length + 2))
        message.instance_variable_set(:@src, src)
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

    attr_reader :raw_data, :src

    def initialize
      # most messages we're sending come from this address
      @src = 0x0a
    end

    def parse(_data)
    end

    def serialize(message = "")
      length = message.length + 5
      full_message = "#{length.chr}#{src.chr}#{self.class::MESSAGE_TYPE}#{message}".force_encoding(Encoding::ASCII_8BIT)
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
