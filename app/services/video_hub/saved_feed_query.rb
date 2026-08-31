# frozen_string_literal: true

module VideoHub
  class SavedFeedQuery
    DEFAULT_LIMIT = 20
    MAX_SCAN_ROWS = 200

    Entry = Struct.new(:video, :bookmark_id, :saved_at, keyword_init: true)
    Result = Struct.new(:entries, :has_more, :next_cursor, keyword_init: true)

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
      rows = candidate_rows(decoded_cursor)
      scan_truncated = rows.length > MAX_SCAN_ROWS
      rows = rows.first(MAX_SCAN_ROWS)
      videos = videos_by_id(rows)
      visible_entries = visible_entries(rows, videos)
      has_more_visible = visible_entries.length > limit
      page_entries = visible_entries.first(limit)
      has_more = has_more_visible || scan_truncated

      Result.new(
        entries: page_entries.freeze,
        has_more: has_more,
        next_cursor: next_cursor(has_more_visible:, scan_truncated:, page_entries:, rows:),
      ).freeze
    rescue SavedFeedCursor::CursorError
      raise FeedError.new(:invalid_cursor)
    rescue ArgumentError, TypeError
      raise FeedError.new(:invalid_limit)
    end

    private

    attr_reader :user, :guardian, :cursor, :limit

    def candidate_rows(decoded_cursor)
      scope =
        Bookmark
          .joins(
            "INNER JOIN video_hub_videos ON video_hub_videos.post_id = bookmarks.bookmarkable_id",
          )
          .joins("INNER JOIN topics ON topics.id = video_hub_videos.topic_id")
          .joins("INNER JOIN posts ON posts.id = video_hub_videos.post_id")
          .where(user_id: user.id, bookmarkable_type: Post.polymorphic_name)
          .where(video_hub_videos: { status: "published", provider: enabled_providers })
          .where.not(video_hub_videos: { published_at: nil })
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
            "bookmarks.updated_at < :saved_at OR (bookmarks.updated_at = :saved_at AND bookmarks.id < :bookmark_id)",
            saved_at: decoded_cursor.saved_at,
            bookmark_id: decoded_cursor.bookmark_id,
          )
      end

      scope
        .order(Arel.sql("bookmarks.updated_at DESC, bookmarks.id DESC"))
        .limit(MAX_SCAN_ROWS + 1)
        .pluck("bookmarks.id", "bookmarks.updated_at", "video_hub_videos.id")
    end

    def videos_by_id(rows)
      ids = rows.map { |row| row.fetch(2) }
      VideoHub::Video.includes(:topic, :post, :user).where(id: ids).index_by(&:id)
    end

    def visible_entries(rows, videos)
      entries = []

      rows.each do |bookmark_id, saved_at, video_id|
        video = videos[video_id]
        next unless VideoHub::WatchQuery.visible_video?(video, guardian: guardian)

        entries << Entry.new(video: video, bookmark_id: bookmark_id, saved_at: saved_at).freeze
        break if entries.length > limit
      end

      entries
    end

    def enabled_providers
      VideoHub::WatchQuery::PROVIDER_SETTINGS.filter_map do |provider, setting|
        provider if SiteSetting.public_send(setting)
      end
    end

    def decode_cursor(value)
      return if value.blank?

      SavedFeedCursor.decode(value)
    end

    def next_cursor(has_more_visible:, scan_truncated:, page_entries:, rows:)
      return unless has_more_visible || scan_truncated

      if has_more_visible
        source = page_entries.last
        return SavedFeedCursor.encode(saved_at: source.saved_at, bookmark_id: source.bookmark_id)
      end

      bookmark_id, saved_at = rows.last
      SavedFeedCursor.encode(saved_at: saved_at, bookmark_id: bookmark_id)
    end
  end
end
