require 'socket'
require 'bwa/message'

module BWA
  class Proxy
    def initialize(host, port: 4257, listen_port: 4257)
      @host, @port = host, port
      @listen_socket = TCPServer.open(port)
    end

    def run
      loop do
        client_socket = @listen_socket.accept
        server_socket = TCPSocket.new(@host, @port)
        t1 = Thread.new do
          shuffle_messages(client_socket, server_socket, "Client")
        end
        t2 = Thread.new do
          shuffle_messages(server_socket, client_socket, "Server")
        end
        t1.join
        t2.join
        break
      end
    end

    def shuffle_messages(socket1, socket2, tag)
      leftover_data = "".force_encoding(Encoding::ASCII_8BIT)
      loop do
        if leftover_data.length < 2 || leftover_data.length < leftover_data[1].ord + 2
          begin
            leftover_data += socket1.recv(128)
          rescue Errno::EBADF
            # we closed it on ourselves
            break
          end
        end
        if leftover_data.empty?
          socket2.close
          break
        end
        data_length = leftover_data[1].ord
        data = leftover_data[0...(data_length + 2)]
        leftover_data = leftover_data[(data_length + 2)..-1] || ''
        begin
          message = Message.parse(data)
          puts "#{tag}: #{message.inspect}"
        rescue InvalidMessage => e
          puts "#{tag}: #{e}"
        end
        socket2.send(data, 0)
      end
    end
  end
end
