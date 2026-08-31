# frozen_string_literal: true

module VideoHub
  class FollowingFeedCursor
    VERSION = 1
    PURPOSE = "video-hub-following-feed-cursor"
    SALT = "video-hub-following-feed-cursor"
    KEY_LENGTH = 32
    TTL = 1.hour
    MAX_LENGTH = 1024

    PAYLOAD_KEYS = %w[version published_microseconds video_id].freeze

    Result = Struct.new(:published_at, :video_id, keyword_init: true)

    class CursorError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    def self.encode(published_at:, video_id:)
      id = Integer(video_id)
      raise CursorError.new(:invalid_cursor) unless id.positive?

      payload = {
        "version" => VERSION,
        "published_microseconds" => timestamp_microseconds(published_at),
        "video_id" => id,
      }

      encryptor.encrypt_and_sign(JSON.generate(payload), purpose: PURPOSE, expires_in: TTL)
    rescue ArgumentError, TypeError, NoMethodError
      raise CursorError.new(:invalid_cursor)
    end

    def self.decode(token)
      raise CursorError.new(:invalid_cursor) unless valid_token_shape?(token)

      payload = JSON.parse(encryptor.decrypt_and_verify(token, purpose: PURPOSE))
      validate_payload!(payload)

      video_id = Integer(payload.fetch("video_id"))
      raise CursorError.new(:invalid_cursor) unless video_id.positive?

      Result.new(
        published_at: time_from_microseconds(payload.fetch("published_microseconds")),
        video_id: video_id,
      ).freeze
    rescue ActiveSupport::MessageEncryptor::InvalidMessage,
           JSON::ParserError,
           KeyError,
           ArgumentError,
           TypeError
      raise CursorError.new(:invalid_cursor)
    end

    def self.validate_payload!(payload)
      raise CursorError.new(:invalid_cursor) unless payload.is_a?(Hash)
      raise CursorError.new(:invalid_cursor) unless payload.keys.sort == PAYLOAD_KEYS.sort
      raise CursorError.new(:invalid_cursor) unless Integer(payload.fetch("version")) == VERSION
    rescue ArgumentError, TypeError
      raise CursorError.new(:invalid_cursor)
    end
    private_class_method :validate_payload!

    def self.valid_token_shape?(token)
      token.is_a?(String) && token.present? && token.bytesize <= MAX_LENGTH &&
        !token.match?(/[[:space:][:cntrl:]]/)
    end
    private_class_method :valid_token_shape?

    def self.timestamp_microseconds(value)
      time = value.to_time
      microseconds = time.to_i * 1_000_000 + time.usec
      raise CursorError.new(:invalid_cursor) unless microseconds.positive?

      microseconds
    end
    private_class_method :timestamp_microseconds

    def self.time_from_microseconds(value)
      microseconds = Integer(value)
      raise CursorError.new(:invalid_cursor) unless microseconds.positive?

      Time.at(Rational(microseconds, 1_000_000)).utc
    end
    private_class_method :time_from_microseconds

    def self.encryptor
      @encryptor ||=
        ActiveSupport::MessageEncryptor.new(
          ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base).generate_key(
            SALT,
            KEY_LENGTH,
          ),
          cipher: "aes-256-gcm",
        )
    end
    private_class_method :encryptor
  end
end
