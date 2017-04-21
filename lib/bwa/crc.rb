require 'digest/crc'

module BWA
  class CRC < Digest::CRC8
    INIT_CRC = 0x02
    XOR_MASK = 0x02
  end
end
