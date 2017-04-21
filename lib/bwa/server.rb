require 'socket'
require 'bwa/message'

module BWA
  class Server
    def initialize(port = 4257)
      @listen_socket = TCPServer.open(port)
      @status = Messages::Status.new
    end

    def run
      loop do
        socket = @listen_socket.accept
        #Thread.new do
          run_client(socket)
        #end
        break
      end
    end

    def send_message(socket, message)
      length = message.length + 2
      full_message = "#{length.chr}#{message}".force_encoding(Encoding::ASCII_8BIT)
      checksum = CRC.checksum(full_message)
      socket.send("\x7e#{full_message}#{checksum.chr}\x7e".force_encoding(Encoding::ASCII_8BIT), 0)
    end

    def run_client(socket)
      puts "Received connection from #{socket.remote_address.inspect}"

      send_status(socket)
      loop do
        if IO.select([socket], nil, nil, 1)
          data = socket.recv(128)
          break if data.empty?
          begin
            message = Message.parse(data)
            puts message.raw_data.unpack("H*").first.scan(/[0-9a-f]{2}/).join(' ')
            puts message.inspect

            case message
            when Messages::ConfigurationRequest
              send_configuration(socket)
            when Messages::ControlConfigurationRequest
              message.type == 1 ? send_control_configuration(socket) : send_control_configuration2(socket)
            when Messages::SetTemperature
              temperature = message.temperature
              temperature /= 2.0 if @status.temperature_scale == :celsius
              @status.set_temperature = temperature
            when Messages::SetTemperatureScale
              @status.temperature_scale = message.scale
            when Messages::ToggleItem
              case message.item
              when :heating_mode
                @status.heating_mode = (@status.heating_mode == :rest ? :ready : :rest)
              when :temperature_range
                @status.temperature_range = (@status.temperature_range == :low ? :high : :low)
              when :pump1
                @status.pump1 = (@status.pump1 + 1) % 3
              when :pump2
                @status.pump2 = (@status.pump2 + 1) % 3
              when :light1
                @status.light1 = !@status.light1
              end
            end
          rescue BWA::InvalidMessage => e
            puts e.message
            puts e.raw_data.unpack("H*").first.scan(/[0-9a-f]{2}/).join(' ')
          end
        else
          send_status(socket)
        end
      end
    end

    def send_status(socket)
      puts "sending #{@status.inspect}"
      socket.send(@status.serialize, 0)
    end

    def send_configuration(socket)
      send_message(socket, "\x0a\xbf\x94\x02\x02\x80\x00\x15\x27\x10\xab\xd2\x00\x00\x00\x00\x00\x00\x00\x00\x00\x15\x27\xff\xff\x10\xab\xd2")
    end

    def send_control_configuration(socket)
      send_message(socket, "\x0a\xbf\x24\x64\xdc\x11\x00\x42\x46\x42\x50\x32\x30\x20\x20\x01\x3d\x12\x38\x2e\x01\x0a\x04\x00")
    end

    def send_control_configuration2(socket)
      send_message(socket, "\x0a\xbf\x2e\x0a\x00\x01\xd0\x00\x44")
    end
  end
end
