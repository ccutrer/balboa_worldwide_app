require 'bwa/message'

module BWA
  class Client
    attr_reader :last_status, :last_filter_configuration

    def initialize(host, port = 4257)
      if host =~ %r{^/dev}
        require 'serialport'
        @io = SerialPort.open(host, "baud" => 115200)
        @queue = []
      else
        require 'socket'
        @io = TCPSocket.new(host, port)
      end
    end

    def poll
      message = nil
      while message.nil?
        begin
          message = Message.parse(@io)
          if message.is_a?(Messages::Ready) && (msg = @queue&.shift)
            puts "wrote #{msg.unpack('H*').first}"
            @io.write(msg)
          end
        rescue BWA::InvalidMessage => e
          unless e.message =~ /Incorrect data length/
            puts e.message
            puts e.raw_data.unpack("H*").first.scan(/[0-9a-f]{2}/).join(' ')
          end
        end
      end
      @last_status = message.dup if message.is_a?(Messages::Status)
      @last_filter_configuration = message.dup if message.is_a?(Messages::FilterCycles)
      message
    end

    def messages_pending?
      !!IO.select([@io], nil, nil, 0)
    end

    def drain_message_queue
      poll while messages_pending?
    end

    def send_message(message)
      length = message.length + 2
      full_message = "#{length.chr}#{message}".force_encoding(Encoding::ASCII_8BIT)
      checksum = CRC.checksum(full_message)
      full_message = "\x7e#{full_message}#{checksum.chr}\x7e".force_encoding(Encoding::ASCII_8BIT)
      if @queue
        @queue.push(full_message)
      else
        @io.write(full_message)
      end
    end

    def request_configuration
      send_message("\x0a\xbf\x04")
    end

    def request_control_info
      send_message("\x0a\xbf\x22\x02\x00\x00")
    end

    def request_filter_configuration
      send_message("\x0a\xbf\x22\x01\x00\x00")
    end

    def toggle_item(args)
      send_message("\x0a\xbf\x11#{args}")
    end

    def toggle_light1
      toggle_item("\x11\x00")
    end

    def toggle_pump1
      toggle_item("\x04\x00")
    end

    def toggle_pump2
      toggle_item("\x05\x00")
    end

    (1..2).each do |i|
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def set_pump#{i}(desired)
        return unless last_status
        times = (desired - last_status.pump#{i}) % 3
        times.times do
          toggle_pump#{i}
          sleep(0.1)
        end
      end
      RUBY
    end

    def set_light1(desired)
      return unless last_status
      return if last_status.light1 == desired
      toggle_light1
    end

    # high range is 80-104 for F, 26-40 for C (by 0.5)
    # low range is 50-80 for F, 10-26 for C (by 0.5)
    def set_temperature(desired)
      desired *= 2 if last_status && last_status.temperature_scale == :celsius || desired < 50
      send_message("\x0a\xbf\x20#{desired.chr}")
    end

    def set_time(hour, minute, twenty_four_hour_time = false)
      hour |= 0x80 if twenty_four_hour_time
      send_message("\x0a\xbf\x21".force_encoding(Encoding::ASCII_8BIT) + hour.chr + minute.chr)
    end

    def set_temperature_scale(scale)
      raise ArgumentError, "scale must be :fahrenheit or :celsius" unless [:fahrenheit, :celsius].include?(scale)
      arg = scale == :fahrenheit ? 0 : 1
      send_message("\x0a\xbf\x27\x01".force_encoding(Encoding::ASCII_8BIT) + arg.chr)
    end

    def set_temperature_range(desired)
      return unless last_status
      return if last_status.temperature_range == desired
      toggle_item("\x50\x00")
    end
  end
end
