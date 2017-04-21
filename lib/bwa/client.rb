require 'socket'
require 'bwa/message'

module BWA
  class Client
    attr_reader :last_status, :last_filter_configuration

    def initialize(host, port = 4257)
      @socket = TCPSocket.new(host, port)
      @leftover_data = "".force_encoding(Encoding::ASCII_8BIT)
    end

    def poll
      if @leftover_data.length < 2 || @leftover_data.length < @leftover_data[1].ord + 2
        @leftover_data += @socket.recv(128)
      end
      data_length = @leftover_data[1].ord
      data = @leftover_data[0...(data_length + 2)]
      @leftover_data = @leftover_data[(data_length + 2)..-1] || ''
      message = Message.parse(data)
      @last_status = message.dup if message.is_a?(Messages::Status)
      @last_filter_configuration = message.dup if message.is_a?(Messages::FilterCycles)
      message
    end

    def messages_pending?
      !!IO.select([@socket], nil, nil, 0)
    end

    def drain_message_queue
      poll while messages_pending?
    end

    def send_message(message)
      length = message.length + 2
      full_message = "#{length.chr}#{message}".force_encoding(Encoding::ASCII_8BIT)
      checksum = CRC.checksum(full_message)
      @socket.send("\x7e#{full_message}#{checksum.chr}\x7e".force_encoding(Encoding::ASCII_8BIT), 0)
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

    def toggle_item(args, checksum = nil)
      send_message("\x0a\xbf\x11#{args}", checksum)
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
      send_message("\x0a\xbf\x21#{hour.chr}#{minute.chr}")
    end
  end
end
