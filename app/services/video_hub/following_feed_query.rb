# frozen_string_literal: true

module VideoHub
  class FollowingFeedQuery
    DEFAULT_LIMIT = 20
    MAX_SCAN_ROWS = 200

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
      @user = user
      @guardian = Guardian.new(user)
      @cursor = cursor
      @limit = limit
    end

    def fetch
      raise FeedError.new(:login_required) unless user

      @limit = Integer(limit)
      raise FeedError.new(:invalid_limit) unless limit.between?(1, DEFAULT_LIMIT)

      decoded_cursor = decode_cursor(cursor)
      followed_user_ids = FollowSource.following_user_ids(user: user)
      rows = candidate_scope(followed_user_ids, decoded_cursor).to_a
      scan_truncated = rows.length > MAX_SCAN_ROWS
      rows = rows.first(MAX_SCAN_ROWS)
      visible_videos = visible_videos(rows)
      has_more_visible = visible_videos.length > limit
      page_videos = visible_videos.first(limit)
      has_more = has_more_visible || scan_truncated

      Result.new(
        videos: page_videos.freeze,
        has_more: has_more,
        next_cursor: next_cursor(has_more_visible:, scan_truncated:, page_videos:, rows:),
      ).freeze
    rescue FollowSource::SourceError => error
      raise FeedError.new(error.code)
    rescue FollowingFeedCursor::CursorError
      raise FeedError.new(:invalid_cursor)
    rescue ArgumentError, TypeError
      raise FeedError.new(:invalid_limit)
    end

    private

    attr_reader :user, :guardian, :cursor, :limit

    def candidate_scope(followed_user_ids, decoded_cursor)
      scope =
        Video
          .joins(:topic, :post)
          .includes(:topic, :post, :user)
          .where(user_id: followed_user_ids)
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

      if decoded_cursor
        scope =
          scope.where(
            "video_hub_videos.published_at < :published_at OR (video_hub_videos.published_at = :published_at AND video_hub_videos.id < :video_id)",
            published_at: decoded_cursor.published_at,
            video_id: decoded_cursor.video_id,
          )
      end

      scope.order(published_at: :desc, id: :desc).limit(MAX_SCAN_ROWS + 1)
    end

    def visible_videos(rows)
      videos = []

      rows.each do |video|
        next unless VideoHub::WatchQuery.visible_video?(video, guardian: guardian)

        videos << video
        break if videos.length > limit
      end

      videos
    end

    def enabled_providers
      VideoHub::WatchQuery::PROVIDER_SETTINGS.filter_map do |provider, setting|
        provider if SiteSetting.public_send(setting)
      end
    end

    def decode_cursor(value)
      return if value.blank?

      FollowingFeedCursor.decode(value)
    end

    def next_cursor(has_more_visible:, scan_truncated:, page_videos:, rows:)
      return unless has_more_visible || scan_truncated

      source = has_more_visible ? page_videos.last : rows.last
      FollowingFeedCursor.encode(published_at: source.published_at, video_id: source.id)
    end
  end
end
