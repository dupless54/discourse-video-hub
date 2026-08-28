# frozen_string_literal: true

require "base64"

module VideoHub
  class FeedQuery
    DEFAULT_LIMIT = 20
    SCAN_BATCH_SIZE = 50
    MAX_SCAN_ROWS = 200
    CURSOR_MAX_LENGTH = 128

    PROVIDER_SETTINGS = {
      "youtube" => :video_hub_youtube_enabled,
      "tiktok" => :video_hub_tiktok_enabled,
      "instagram" => :video_hub_instagram_enabled,
    }.freeze

    Result = Struct.new(:videos, :has_more, :next_cursor, keyword_init: true)

    class FeedError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    def self.fetch(user:, cursor: nil, limit: DEFAULT_LIMIT)
      new(user: user, cursor: cursor, limit: limit).fetch
    end

    def initialize(user:, cursor:, limit:)
      @guardian = Guardian.new(user)
      @cursor = cursor
      @limit = Integer(limit)
    end

    def fetch
      raise FeedError.new(:invalid_limit) unless limit.between?(1, DEFAULT_LIMIT)

      position = decode_cursor(cursor)
      visible = []
      scanned = 0
      last_scanned = nil
      exhausted = false

      while visible.length <= limit && scanned < MAX_SCAN_ROWS
        batch_limit = [SCAN_BATCH_SIZE, MAX_SCAN_ROWS - scanned].min
        batch = candidate_scope(position).limit(batch_limit).to_a

        if batch.empty?
          exhausted = true
          break
        end

        batch.each do |video|
          position = [video.published_at, video.id]
          last_scanned = video
          scanned += 1
          visible << video if visible_to_guardian?(video)
          break if visible.length > limit || scanned >= MAX_SCAN_ROWS
        end

        break if visible.length > limit || scanned >= MAX_SCAN_ROWS

        if batch.length < batch_limit
          exhausted = true
          break
        end
      end

      page = visible.first(limit)
      has_more = visible.length > limit || (!exhausted && scanned >= MAX_SCAN_ROWS)
      cursor_source = page.length == limit ? page.last : last_scanned

      Result.new(
        videos: page.freeze,
        has_more: has_more,
        next_cursor: has_more && cursor_source ? encode_cursor(cursor_source) : nil,
      ).freeze
    rescue ArgumentError, TypeError
      raise FeedError.new(:invalid_limit)
    end

    private

    attr_reader :guardian, :cursor, :limit

    def candidate_scope(position)
      scope =
        Video
          .joins(:topic, :post)
          .includes(:topic, :post, :user)
          .where(status: "published", provider: enabled_providers)
          .where.not(published_at: nil)
          .where(
            topics: {
              category_id: guardian.allowed_category_ids,
              deleted_at: nil,
              visible: true,
            },
            posts: {
              deleted_at: nil,
              hidden: false,
            },
          )
          .order(published_at: :desc, id: :desc)

      return scope unless position

      published_at, id = position
      scope.where(
        "video_hub_videos.published_at < :published_at OR " \
          "(video_hub_videos.published_at = :published_at AND video_hub_videos.id < :id)",
        published_at: published_at,
        id: id,
      )
    end

    def enabled_providers
      PROVIDER_SETTINGS.filter_map do |provider, setting|
        provider if SiteSetting.public_send(setting)
      end
    end

    def visible_to_guardian?(video)
      guardian.can_see?(video.topic) && guardian.can_see?(video.post)
    end

    def encode_cursor(video)
      microseconds = video.published_at.to_i * 1_000_000 + video.published_at.usec
      Base64.urlsafe_encode64("#{microseconds}:#{video.id}", padding: false)
    end

    def decode_cursor(value)
      return if value.blank?
      raise FeedError.new(:invalid_cursor) unless value.is_a?(String)
      raise FeedError.new(:invalid_cursor) if value.length > CURSOR_MAX_LENGTH
      raise FeedError.new(:invalid_cursor) if value.match?(/[[:space:][:cntrl:]]/)

      decoded = Base64.urlsafe_decode64(value)
      match = decoded.match(/\A([0-9]{1,20}):([0-9]{1,20})\z/)
      raise FeedError.new(:invalid_cursor) unless match

      microseconds = Integer(match[1], 10)
      id = Integer(match[2], 10)
      raise FeedError.new(:invalid_cursor) if microseconds <= 0 || id <= 0

      [Time.at(Rational(microseconds, 1_000_000)).utc, id]
    rescue ArgumentError
      raise FeedError.new(:invalid_cursor)
    end
  end
end
