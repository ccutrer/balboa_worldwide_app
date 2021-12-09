module BWA
  module Messages
    class ControlConfiguration < Message
      MESSAGE_TYPE = "\xbf\x24".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 21

      attr_accessor :model, :version

      def initialize
        super
        @model = ""
        @version = 0
      end

      def parse(data)
        self.version = "V#{data[2].ord}.#{data[3].ord}"
        self.model = data[4..11].strip
      end

      def inspect
        "#<BWA::Messages::ControlConfiguration #{model} #{version}>"
      end
    end

    class ControlConfiguration2 < Message
      MESSAGE_TYPE = "\xbf\x2e".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 6

      attr_accessor :pumps, :lights, :circ_pump, :blower, :mister, :aux

      def initialize
        self.pumps = Array.new(6, 0)
        self.lights = Array.new(2, false)
        self.circ_pump = false
        self.blower = 0
        self.mister = false
        self.aux = Array.new(2, false)
      end

      def parse(data)
        flags = data[0].ord
        pumps[0] = flags & 0x03
        pumps[1] = (flags >> 2) & 0x03
        pumps[2] = (flags >> 4) & 0x03
        pumps[3] = (flags >> 6) & 0x03
        flags = data[1].ord
        pumps[4] = flags & 0x03
        pumps[5] = (flags >> 6) & 0x03
        flags = data[2].ord
        lights[0] = (flags & 0x03 != 0)
        lights[1] = ((flags >> 6) & 0x03 != 0)
        flags = data[3].ord
        self.blower = flags & 0x03
        self.circ_pump = ((flags >> 6) & 0x03 != 0)
        flags = data[4].ord
        self.mister = (flags & 0x30 != 0)
        aux[0] = (flags & 0x01 != 0)
        aux[1] = (flags & 0x02 != 0)
      end

      def inspect
        result = "#<BWA::Messages::ControlConfiguration2 "
        items = []

        items << "pumps=#{pumps.inspect}"
        items << "lights=#{lights.inspect}"
        items << "circ_pump" if circ_pump
        items << "blower=#{blower}" if blower != 0
        items << "mister" if mister
        items << "aux=#{aux.inspect}"

        result << items.join(" ") << ">"
      end
    end
  end
end
