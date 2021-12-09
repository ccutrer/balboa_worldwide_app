# frozen_string_literal: true

require "socket"
require "bwa/logger"

module BWA
  class Discovery
    class << self
      def discover(timeout = 5, exhaustive = false)
        socket = UDPSocket.new
        socket.bind("0.0.0.0", 0)
        socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
        socket.sendmsg("Discovery: Who is out there?", 0, Socket.sockaddr_in(30_303, "255.255.255.255"))
        spas = {}
        loop do
          if socket.wait_readable(timeout)
            msg, ip = socket.recvfrom(64)
            ip = ip[2]
            name, mac = msg.split("\r\n")
            name.strip!
            if mac.start_with?("00-15-27-")
              spas[ip] = name
              break unless exhaustive
            end
          else
            break
          end
        end
        spas
      end

      def advertise
        socket = UDPSocket.new
        socket.bind("0.0.0.0", 30_303)
        msg = "BWGSPA\r\n00-15-27-00-00-01\r\n"
        loop do
          data, addr = socket.recvfrom(32)
          next unless data == "Discovery: Who is out there?"

          ip = addr.last
          BWA.logger.info "Advertising to #{ip}"
          socket.sendmsg(msg, 0, Socket.sockaddr_in(addr[1], ip))
        end
      end
    end
  end
end
