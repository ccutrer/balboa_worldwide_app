require 'logger'

module BWA
  # This module logs to stdout by default, or you can provide a logger as BWA.logger.
  # If using default logger, set LOG_LEVEL in the environment to control logging.
  #
  # Log levels are:
  #
  # FATAL - fatal errors
  # ERROR - handled errors
  # WARN  - problems while parsing known messages
  # INFO  - unrecognized messages
  # DEBUG - all messages
  #
  # Certain very frequent messages are suppressed by default even in DEBUG mode.
  # Set LOG_VERBOSITY to one of the following levels to see these:
  #
  # 0 - default
  # 1 - show status messages
  # 2 - show ready and nothing-to-send messages
  #
  class << self
    attr_writer :logger, :verbosity

    def logger
      @logger ||= Logger.new(STDOUT).tap do |log|
        STDOUT.sync = true
        log.level = ENV.fetch("LOG_LEVEL","WARN")
        log.formatter = proc do |severity, datetime, progname, msg|
          "#{severity[0..0]}, #{msg2logstr(msg)}\n"
        end
      end
    end

    def verbosity
      @verbosity ||= ENV.fetch("LOG_VERBOSITY", "0").to_i
      @verbosity
    end

    def msg2logstr(msg)
      case msg
      when ::String
        msg
      when ::Exception
        "#{ msg.message } (#{ msg.class })\n#{ msg.backtrace.join("\n") if msg.backtrace }"
      else
        msg.inspect
      end
    end

    def raw2str(data)
      data.unpack("H*").first.gsub!(/(..)/, "\\1 ").chop!
    end
  end
end
