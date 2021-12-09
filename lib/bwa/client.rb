# frozen_string_literal: true

require "uri"

require "bwa/logger"
require "bwa/message"

module BWA
  class Client
    attr_reader :last_status, :last_control_configuration, :last_control_configuration2, :last_filter_configuration

    def initialize(uri)
      uri = URI.parse(uri)
      case uri.scheme
      when "tcp"
        require "socket"
        @io = TCPSocket.new(uri.host, uri.port || 4257)
      when "telnet", "rfc2217"
        require "net/telnet/rfc2217"
        @io = Net::Telnet::RFC2217.new("Host" => uri.host, "Port" => uri.port || 23, "baud" => 115_200)
        @queue = []
      else
        require "ccutrer-serialport"
        @io = CCutrer::SerialPort.new(uri.path, baud: 115_200)
        @queue = []
      end
      @src = 0x0a
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
        unless BWA.verbosity < 1 && msg[3..4] == Messages::ControlConfigurationRequest::MESSAGE_TYPE
          BWA.logger.debug "wrote: #{BWA.raw2str(msg)}"
        end
        @io.write(msg)
      end
      @last_status = message.dup if message.is_a?(Messages::Status)
      @last_filter_configuration = message.dup if message.is_a?(Messages::FilterCycles)
      @last_control_configuration = message.dup if message.is_a?(Messages::ControlConfiguration)
      @last_control_configuration2 = message.dup if message.is_a?(Messages::ControlConfiguration2)
      message
    end

    def messages_pending?
      !!@io.wait_readable(0)
    end

    def drain_message_queue
      poll while messages_pending?
    end

    def send_message(message)
      message.src = @src
      full_message = message.serialize
      unless BWA.verbosity < 1 && message.is_a?(Messages::ControlConfigurationRequest)
        BWA.logger.info "  to spa: #{message.inspect}"
      end
      if @queue
        @queue.push(full_message)
      else
        unless BWA.verbosity < 1 && message.is_a?(Messages::ControlConfigurationRequest)
          BWA.logger.debug "wrote: #{BWA.raw2str(full_message)}"
        end
        @io.write(full_message)
      end
    end

    def request_configuration
      send_message(Messages::ConfigurationRequest.new)
    end

    def request_control_info2
      send_message(Messages::ControlConfigurationRequest.new(2))
    end

    def request_control_info
      send_message(Messages::ControlConfigurationRequest.new(1))
    end

    def request_filter_configuration
      send_message(Messages::ControlConfigurationRequest.new(3))
    end

    def toggle_item(item)
      send_message(Messages::ToggleItem.new(item))
    end

    def toggle_pump(index)
      toggle_item(index + 3)
    end

    def toggle_light(index)
      toggle_item(index + 0x10)
    end

    def toggle_mister
      toggle_item(:mister)
    end

    def toggle_blower
      toggle_item(:blower)
    end

    def toggle_hold
      toggle_item(:hold)
    end

    def set_pump(index, desired)
      return unless last_status && last_control_configuration2

      times = (desired - last_status.pumps[index - 1]) % (last_control_configuration2.pumps[index - 1] + 1)
      times.times do
        toggle_pump(index)
        sleep(0.1)
      end
    end

    %w[light aux].each do |type|
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def set_#{type}(index, desired)
          return unless last_status
          return if last_status.#{type}s[index - 1] == desired
          toggle_#{type}(index)
        end
      RUBY
    end

    def mister=(desired)
      return unless last_status
      return if last_status.mister == desired

      toggle_mister
    end

    def blower=(desired)
      return unless last_status && last_control_configuration2

      times = (desired - last_status.blower) % (last_control_configuration2.blower + 1)
      times.times do
        toggle_blower
        sleep(0.1)
      end
    end

    def hold=(desired)
      return unless last_status
      return if last_status.hold == desired

      toggle_hold
    end

    # high range is 80-106 for F, 26-40 for C (by 0.5)
    # low range is 50-99 for F, 10-26 for C (by 0.5)
    def set_temperature=(desired) # rubocop:disable Naming/AccessorMethodName
      return unless last_status
      return if last_status.set_temperature == desired

      desired *= 2 if (last_status && last_status.temperature_scale == :celsius) || desired < 50
      send_message(Messages::SetTemperature.new(desired.round))
    end

    def set_time(hour, minute, twenty_four_hour_time = false)
      send_message(Messages::SetTime.new(hour, minute, twenty_four_hour_time))
    end

    def temperature_scale=(scale)
      raise ArgumentError, "scale must be :fahrenheit or :celsius" unless %I[fahrenheit celsius].include?(scale)

      send_message(Messages::SetTemperatureScale.new(scale))
    end

    def set_filtercycles(changed_item, changed_value)
      # changed_item - String name of item that was changed
      # changed_value - String value of the item that changed
      return unless last_filter_configuration

      send_message(Messages::FilterCycles.new(changed_item, changed_value, @last_filter_configuration))
      request_filter_configuration
      # Need to wait briefly to let the next message come in from the spa in order to update last_filter_configuration
      # needed when automation quickly sets multiple values one right after the other
      sleep(0.2)
    end

    def toggle_temperature_range
      toggle_item(0x50)
    end

    def temperature_range=(desired)
      return unless last_status
      return if last_status.temperature_range == desired

      toggle_temperature_range
    end

    def toggle_heating_mode
      toggle_item(:heating_mode)
    end

    HEATING_MODES = %I[ready rest ready_in_rest].freeze
    def heating_mode=(desired)
      raise ArgumentError, "heating_mode must be :ready or :rest" unless %I[ready rest].include?(desired)
      return unless last_status

      times = if (last_status.heating_mode == :ready && desired == :rest) ||
                 (last_status.heating_mode == :rest && desired == :ready) ||
                 (last_status.heating_mode == :ready_in_rest && desired == :rest)
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
