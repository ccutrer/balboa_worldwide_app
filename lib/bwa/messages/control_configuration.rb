module BWA
  module Messages
    class ControlConfiguration < Message
      MESSAGE_TYPE = "\x0a\xbf\x24".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 21
    end
  end
end

module BWA
  module Messages
    class ControlConfiguration2 < Message
      MESSAGE_TYPE = "\x0a\xbf\x2e".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 6
    end
  end
end
