# frozen_string_literal: true

module BWA
  # The spa's music system (the bba amplifier): what it last reported, and the
  # commands to control it. Changes show up here once the amplifier reports
  # them.
  #
  # The amplifier only reports changes, so after connecting it has to be asked
  # for each part of its state (see #refresh). Answers sometimes go missing,
  # so whatever has not arrived is asked for again.
  class Audio
    # What each Messages::Audio::Command :request argument asks for, by index.
    REQUESTS = %i[playback volume bluetooth power title album artist].freeze
    TEXT = %i[title album artist].freeze
    # Seconds between requests.
    REQUEST_INTERVAL = 1.5
    # Requests to send before deciding there is no amplifier (until one is heard).
    PROBES = 5
    # The amplifier's play state flickers to paused while playing, and stays at
    # playing when the phone pauses by itself. So: playing means the position
    # moved within this many seconds.
    PLAYING_GRACE = 3

    attr_reader :power,
                :source,
                :repeat,
                :volume,
                :max_volume,
                :muted,
                :bluetooth_name,
                :bluetooth_address,
                :device_connected
    alias_method :on?, :power
    alias_method :muted?, :muted
    alias_method :device_connected?, :device_connected

    def initialize(client)
      @client = client
      @missing = REQUESTS.dup
      @text = {}
      @probes = 0
      @next_request_at = nil
      @heard = false
    end

    # Whether an amplifier has said anything.
    def heard?
      @heard
    end

    def bluetooth?
      source == :bluetooth
    end

    def shuffle?
      @shuffle
    end

    # :playing, :paused or :stopped; nil unless on Bluetooth.
    def playback(now = self.class.now)
      return unless bluetooth? && @play_state
      return :stopped if @play_state == :stopped

      (@moved_at && now - @moved_at < PLAYING_GRACE) ? :playing : :paused
    end

    # The song's position and length in seconds; nil unless a song is loaded.
    def position
      @position if song?
    end

    def duration
      @duration if song?
    end

    TEXT.each do |field|
      define_method(field) { @text[field] if bluetooth? && device_connected? }
    end

    # Takes in a message; true if it was the music system's.
    def update(message, now = self.class.now)
      case message
      when Messages::Audio::Playback then update_playback(message, now)
      when Messages::Audio::Text then update_text(message)
      when Messages::Audio::Volume then update_volume(message)
      when Messages::Audio::Bluetooth then update_bluetooth(message)
      when Messages::Audio::Power then update_power(message)
      when Messages::Audio::Command
        # The pack passing on a command (ours, or the panel's).
        return false if message.src == 0x0a

        update_command(message, now)
        return true
      else
        return false
      end
      @heard = true
    end

    # Asks the amplifier for the next part of its state that has not been
    # heard yet. Call it regularly; it limits itself.
    def refresh(now = self.class.now)
      index = next_request(now)
      send_command(:request, index) if index
    end

    def send_command(command, argument = 0)
      @client.send_message(Messages::Audio::Command.new(command, argument))
    end

    def power=(desired)
      send_command(:power, desired ? 1 : 0)
    end

    def source=(source)
      code = Messages::Audio::Playback::SOURCES.key(source)
      raise ArgumentError, "source must be :bluetooth or :line" unless code

      send_command(:source, code)
    end

    def play
      send_command(:play)
    end

    def pause
      send_command(:pause)
    end

    def next
      send_command(:next)
    end

    def previous
      send_command(:previous)
    end

    def volume=(volume)
      send_command(:volume, volume.clamp(0, max_volume || 0xff))
    end

    def muted=(desired)
      send_command(:mute, desired ? 1 : 0)
    end

    def repeat=(mode)
      code = Messages::Audio::Playback::REPEAT_MODES.key(mode)
      raise ArgumentError, "repeat must be :off, :one or :all" unless code

      send_command(:repeat, code)
    end

    def shuffle=(desired)
      send_command(:shuffle, desired ? 1 : 0)
    end

    def self.now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    private

    # The index of the next :request to send, or nil for none now.
    def next_request(now)
      return if @next_request_at && now < @next_request_at
      return if !heard? && @probes >= PROBES

      wanted = REQUESTS & @missing
      wanted -= TEXT if device_connected == false || source == :line # no phone, no song
      return if wanted.empty?

      @probes += 1 unless heard?
      @next_request_at = now + REQUEST_INTERVAL
      REQUESTS.index(wanted.first)
    end

    def song?
      bluetooth? && @duration&.positive?
    end

    def update_playback(message, now)
      @moved_at = now if @position && message.position != @position
      # a new song: its text usually comes by itself, this makes sure
      @missing |= TEXT if @duration && message.duration != @duration && message.source == :bluetooth
      @source = message.source
      @play_state = message.state
      @position = message.position
      @duration = message.duration
      @repeat = message.repeat
      @shuffle = message.shuffle
      @missing.delete(:playback)
    end

    def update_text(message)
      return unless TEXT.include?(message.field)

      @text[message.field] = message.text.empty? ? nil : message.text
      @missing.delete(message.field)
    end

    def update_volume(message)
      @volume = message.volume
      @muted = message.muted
      @max_volume = message.max_volume
      @missing.delete(:volume)
    end

    def update_bluetooth(message)
      @missing |= TEXT if message.connected && device_connected == false # a phone just connected
      @text = {} unless message.connected
      @device_connected = message.connected
      @bluetooth_name = message.name.empty? ? nil : message.name
      @bluetooth_address = message.address
      @missing.delete(:bluetooth)
    end

    def update_power(message)
      @missing = REQUESTS - [:power] if message.on && power == false # it starts again from scratch
      @power = message.on
      @missing.delete(:power)
    end

    def update_command(message, now)
      case message.command
      when :play
        # show it at once instead of waiting for the position to move
        @moved_at = now
        @play_state = :playing if @play_state
      when :pause
        @moved_at = nil
        @play_state = :paused if @play_state
      end
    end
  end
end
