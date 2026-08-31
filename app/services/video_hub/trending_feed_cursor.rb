# frozen_string_literal: true

module VideoHub
  class TrendingFeedCursor
    PURPOSE = "video-hub-trending-feed-cursor"
    SALT = "video-hub-trending-feed-cursor"
    KEY_LENGTH = 32
    TTL = 1.hour
    MAX_LENGTH = 2048

    class CursorError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    def self.encode(context:, score_basis_points:, published_at:, video_id:)
      ranking_token =
        RankingCursor.encode(
          context: context,
          score_basis_points: score_basis_points,
          published_at: published_at,
          video_id: video_id,
        )

      encryptor.encrypt_and_sign(ranking_token, purpose: PURPOSE, expires_in: TTL)
    rescue RankingCursor::CursorError, ArgumentError, TypeError
      raise CursorError.new(:invalid_cursor)
    end

    def self.decode(token)
      raise CursorError.new(:invalid_cursor) unless valid_token_shape?(token)

      ranking_token = encryptor.decrypt_and_verify(token, purpose: PURPOSE)
      RankingCursor.decode(ranking_token)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage,
           RankingCursor::CursorError,
           ArgumentError,
           TypeError
      raise CursorError.new(:invalid_cursor)
    end

    def self.valid_token_shape?(token)
      token.is_a?(String) && token.present? && token.bytesize <= MAX_LENGTH &&
        !token.match?(/[[:space:][:cntrl:]]/)
    end
    private_class_method :valid_token_shape?

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
