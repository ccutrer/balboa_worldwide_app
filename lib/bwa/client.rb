# frozen_string_literal: true

require "forwardable"
require "uri"

require "bwa/logger"
require "bwa/message"

module BWA
  class Client
    extend Forwardable

    attr_reader :status, :control_configuration, :configuration, :filter_cycles

    delegate model: :control_configuration
    delegate %i[hold
                hold?
                priming
                priming?
                notification
                heating_mode
                temperature_scale
                twenty_four_hour_time
                twenty_four_hour_time?
                heating
                heating?
                temperature_range
                current_temperature
                target_temperature
                circulation_pump
                blower
                mister
                pumps
                lights
                aux] => :status

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
      @buffer = +""
    end

    def full_configuration?
      status && control_configuration && configuration && filter_cycles
    end

    def poll
      message = bytes_read = nil
      loop do
        message, bytes_read = Message.parse(@buffer)
        # discard how much we read
        @buffer = @buffer[bytes_read..-1] if bytes_read
        method = @io.respond_to?(:readpartial) ? :readpartial : :read
        unless message
          # one EOF is just serial ports saying they have no data;
          # several EOFs in a row is the file is dead and gone
          eofs = 0
          begin
            @buffer.concat(@io.__send__(method, 64 * 1024))
          rescue EOFError
            eofs += 1
            raise if eofs == 5

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
      @status = message.dup if message.is_a?(Messages::Status)
      @filter_cycles = message.dup if message.is_a?(Messages::FilterCycles)
      @control_configuration = message.dup if message.is_a?(Messages::ControlConfiguration)
      @configuration = message.dup if message.is_a?(Messages::ControlConfiguration2)
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
      toggle_item(index + 0x04)
    end

    def toggle_light(index)
      toggle_item(index + 0x11)
    end

    def toggle_aux(index)
      toggle_item(index + 0x16)
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
      return unless status && configuration

      desired = 0 if desired == false
      max_pump_speed = configuration.pumps[index]
      desired = max_pump_speed if desired == true
      desired = [desired, max_pump_speed].min
      current_pump_speed = [status.pumps[index], max_pump_speed].min
      times = (desired - current_pump_speed) % (max_pump_speed + 1)
      times.times do |i|
        toggle_pump(index)
        sleep(0.1) unless i == times - 1
      end
    end

    %i[light aux].each do |type|
      suffix = "s" if type == :light
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def set_#{type}(index, desired)
          return unless status
          return if status.#{type}#{suffix}[index] == desired

          toggle_#{type}(index)
        end
      RUBY
    end

    def mister=(desired)
      return unless status
      return if status.mister == desired

      toggle_mister
    end

    def blower=(desired)
      return unless status && configuration

      desired = 0 if desired == false
      desired = configuration.blower if desired == true
      desired = [desired, configuration.blower].min
      times = (desired - status.blower) % (configuration.blower + 1)
      times.times do |i|
        toggle_blower
        sleep(0.1) unless i == times - 1
      end
    end

    def hold=(desired)
      return unless status
      return if status.hold == desired

      toggle_hold
    end

    # high range is 80-106 for F, 26-40 for C (by 0.5)
    # low range is 50-99 for F, 10-26 for C (by 0.5)
    def target_temperature=(desired)
      return unless status
      return if status.target_temperature == desired

      desired *= 2 if (status && status.temperature_scale == :celsius) || desired < 50
      send_message(Messages::SetTargetTemperature.new(desired.round))
    end

    def set_time(hour, minute, twenty_four_hour_time: false)
      send_message(Messages::SetTime.new(hour, minute, twenty_four_hour_time))
    end

    def temperature_scale=(scale)
      raise ArgumentError, "scale must be :fahrenheit or :celsius" unless %I[fahrenheit celsius].include?(scale)

      send_message(Messages::SetTemperatureScale.new(scale))
    end

    def update_filter_cycles(new_filter_cycles)
      send_message(new_filter_cycles)
      @filter_cycles = new_filter_cycles.dup
      request_filter_configuration
    end

    def toggle_temperature_range
      toggle_item(0x50)
    end

    def temperature_range=(desired)
      return unless status
      return if status.temperature_range == desired

      toggle_temperature_range
    end

    def toggle_heating_mode
      toggle_item(:heating_mode)
    end

    HEATING_MODES = %I[ready rest ready_in_rest].freeze
    def heating_mode=(desired)
      raise ArgumentError, "heating_mode must be :ready or :rest" unless %I[ready rest].include?(desired)
      return unless status

      times = if (status.heating_mode == :ready && desired == :rest) ||
                 (status.heating_mode == :rest && desired == :ready) ||
                 (status.heating_mode == :ready_in_rest && desired == :rest)
                1
              elsif status.heating_mode == :ready_in_rest && desired == :ready
                2
              else
                0
              end
      times.times do |i|
        toggle_heating_mode
        sleep(0.1) unless i == times - 1
      end
    end
  end
end
