# frozen_string_literal: true

module VideoHub
  class RankingCursor
    VERSION = 1
    PURPOSE = "video-hub-ranking-cursor"
    SALT = "video-hub-ranking-cursor"
    KEY_LENGTH = 32
    TTL = 1.hour
    MAX_LENGTH = 1024

    PAYLOAD_KEYS = %w[
      version
      context_version
      score_version
      snapshot_microseconds
      metric_as_of
      weights
      score_basis_points
      published_microseconds
      video_id
    ].freeze

    Result = Struct.new(:context, :score_basis_points, :published_at, :video_id, keyword_init: true)

    class CursorError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    def self.encode(context:, score_basis_points:, published_at:, video_id:)
      score = Integer(score_basis_points)
      id = Integer(video_id)
      raise CursorError.new(:invalid_cursor) unless context.is_a?(RankingContext)
      raise CursorError.new(:invalid_cursor) unless context.version == RankingContext::VERSION
      unless score.between?(0, RankingScore::MAX_BASIS_POINTS)
        raise CursorError.new(:invalid_cursor)
      end
      raise CursorError.new(:invalid_cursor) unless id.positive?

      payload = {
        "version" => VERSION,
        "context_version" => context.version,
        "score_version" => RankingScore::VERSION,
        "snapshot_microseconds" => timestamp_microseconds(context.snapshot_at),
        "metric_as_of" => context.metric_as_of.iso8601,
        "weights" => context.weights.transform_keys(&:to_s),
        "score_basis_points" => score,
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

      weights =
        RankingScore::WEIGHT_SETTINGS.keys.index_with do |name|
          payload.fetch("weights").fetch(name.to_s)
        end
      context =
        RankingContext.restore(
          snapshot_at: time_from_microseconds(payload.fetch("snapshot_microseconds")),
          metric_as_of: Date.iso8601(payload.fetch("metric_as_of")),
          weights: weights,
          version: payload.fetch("context_version"),
        )
      score = Integer(payload.fetch("score_basis_points"))
      video_id = Integer(payload.fetch("video_id"))
      published_at = time_from_microseconds(payload.fetch("published_microseconds"))
      unless score.between?(0, RankingScore::MAX_BASIS_POINTS)
        raise CursorError.new(:invalid_cursor)
      end
      raise CursorError.new(:invalid_cursor) unless video_id.positive?

      Result.new(
        context: context,
        score_basis_points: score,
        published_at: published_at,
        video_id: video_id,
      ).freeze
    rescue ActiveSupport::MessageEncryptor::InvalidMessage,
           JSON::ParserError,
           KeyError,
           ArgumentError,
           TypeError,
           RankingContext::ContextError,
           RankingScore::RankingError
      raise CursorError.new(:invalid_cursor)
    end

    def self.validate_payload!(payload)
      raise CursorError.new(:invalid_cursor) unless payload.is_a?(Hash)
      raise CursorError.new(:invalid_cursor) unless payload.keys.sort == PAYLOAD_KEYS.sort
      raise CursorError.new(:invalid_cursor) unless Integer(payload.fetch("version")) == VERSION
      unless Integer(payload.fetch("context_version")) == RankingContext::VERSION &&
               Integer(payload.fetch("score_version")) == RankingScore::VERSION
        raise CursorError.new(:invalid_cursor)
      end

      weights = payload.fetch("weights")
      expected_weight_keys = RankingScore::WEIGHT_SETTINGS.keys.map(&:to_s).sort
      unless weights.is_a?(Hash) && weights.keys.sort == expected_weight_keys
        raise CursorError.new(:invalid_cursor)
      end
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
