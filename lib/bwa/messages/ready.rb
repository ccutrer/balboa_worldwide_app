module BWA
  module Messages
    class Ready < Message
      MESSAGE_TYPE = "\x10\xbf\06".force_encoding(Encoding::ASCII_8BIT)
      MESSAGE_LENGTH = 0
    end
  end
end
