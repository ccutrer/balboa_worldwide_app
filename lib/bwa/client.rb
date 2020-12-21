require 'bwa/message'

module BWA
  class Client
    attr_reader :last_status, :last_control_configuration, :last_control_configuration2, :last_filter_configuration

    def initialize(uri)
      uri = URI.parse(uri)
      if uri.scheme == 'tcp'
        require 'socket'
        @io = TCPSocket.new(uri.host, uri.port || 4217)
      elsif uri.scheme == 'telnet' || uri.scheme == 'rfc2217'
        require 'net/telnet/rfc2217'
        @io = Net::Telnet::RFC2217.new("Host" => uri.host, "Port" => uri.port || 23, "baud" => 115200)
        @queue = []
      else
        require 'ccutrer-serialport'
        @io = CCutrer::SerialPort.new(uri.path, baud: 115200)
        @queue = []
      end
      @buffer = ""
    end

    def poll
      message = bytes_read = nil
      loop do
        message, bytes_read = Message.parse(@buffer)
        # discard how much we read
        @buffer = @buffer[bytes_read..-1] if bytes_read
        method = @io.respond_to?(:readpartial) ? :readpartial : :read
        unless message
          begin
            @buffer.concat(@io.__send__(method, 64 * 1024))
          rescue EOFError
            @io.wait_readable
            retry
          end
          next
        end
        break
      end

      if message.is_a?(Messages::Ready) && (msg = @queue&.shift)
        puts "wrote #{msg.unpack('H*').first}"
        @io.write(msg)
      end
      @last_status = message.dup if message.is_a?(Messages::Status)
      @last_filter_configuration = message.dup if message.is_a?(Messages::FilterCycles)
      @last_control_configuration = message.dup if message.is_a?(Messages::ControlConfiguration)
      @last_control_configuration2 = message.dup if message.is_a?(Messages::ControlConfiguration2)
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

    def request_control_info2
      send_message("\x0a\xbf\x22\x00\x00\x01")
    end

    def request_control_info
      send_message("\x0a\xbf\x22\x02\x00\x00")
    end

    def request_filter_configuration
      send_message("\x0a\xbf\x22\x01\x00\x00")
    end

    def toggle_item(item)
      send_message("\x0a\xbf\x11#{item.chr}\x00")
    end

    def toggle_pump(i)
      toggle_item(i + 3)
    end

    def toggle_light(i)
      toggle_item(i + 0x10)
    end

    def toggle_mister
      toggle_item(0x0e)
    end

    def toggle_blower
      toggle_item(0x0c)
    end

    def set_pump(i, desired)
      return unless last_status && last_control_configuration2
      times = (desired - last_status.pumps[i - 1]) % (last_control_configuration2.pumps[i - 1] + 1)
      times.times do
        toggle_pump(i)
        sleep(0.1)
      end
    end

    %w{light aux}.each do |type|
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def set_#{type}(i, desired)
          return unless last_status
          return if last_status.#{type}s[i - 1] == desired
          toggle_#{type}(i)
        end
      RUBY
    end

    def set_mister(desired)
      return unless last_status
      return if last_status.mister == desired
      toggle_mister
    end

    def set_blower(desired)
      return unless last_status && last_control_configuration2
      times = (desired - last_status.blower) % (last_control_configuration2.blower + 1)
      times.times do
        toggle_blower
        sleep(0.1)
      end
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
      raise ArgumentError, "scale must be :fahrenheit or :celsius" unless %I{fahrenheit :celsius}.include?(scale)
      arg = scale == :fahrenheit ? 0 : 1
      send_message("\x0a\xbf\x27\x01".force_encoding(Encoding::ASCII_8BIT) + arg.chr)
    end

    def toggle_temperature_range
      toggle_item(0x50)
    end

    def set_temperature_range(desired)
      return unless last_status
      return if last_status.temperature_range == desired
      toggle_temperature_range
    end

    def toggle_heating_mode
      toggle_item(0x51)
    end

    HEATING_MODES = %I{ready rest ready_in_rest}.freeze
    def set_heating_mode(desired)
      raise ArgumentError, "heating_mode must be :ready or :rest" unless %I{ready rest}.include?(desired)
      return unless last_status
      times = if last_status.heating_mode == :ready && desired == :rest ||
                 last_status.heating_mode == :rest && desired == :ready ||
                 last_status.heating_mode == :ready_in_rest && desired == :rest
          1
        elsif last_status.heating_mode == :ready_in_rest && desired == :ready
          2
        else
          0
        end
      times.times { toggle_heating_mode }
    end
  end
end
