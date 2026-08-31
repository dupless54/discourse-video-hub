# frozen_string_literal: true

module VideoHub
  class TrendingFeedQuery
    DEFAULT_LIMIT = 20
    MAX_SCAN_ROWS = 200

    Result = Struct.new(:videos, :has_more, :next_cursor, keyword_init: true)
    RankedEntry =
      Struct.new(:video, :score_basis_points, :published_microseconds, keyword_init: true)

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

      decoded_cursor = decode_cursor(cursor)
      context = decoded_cursor&.context || RankingContext.capture
      ranked = ranked_candidates(context)
      ranked = ranked.select { |entry| after_cursor?(entry, decoded_cursor) } if decoded_cursor
      page_entries = ranked.first(limit + 1)
      has_more = page_entries.length > limit
      page_entries = page_entries.first(limit)
      cursor_source = page_entries.last

      Result.new(
        videos: page_entries.map(&:video).freeze,
        has_more: has_more,
        next_cursor: has_more && cursor_source ? encode_cursor(context, cursor_source) : nil,
      ).freeze
    rescue TrendingFeedCursor::CursorError
      raise FeedError.new(:invalid_cursor)
    rescue ArgumentError, TypeError
      raise FeedError.new(:invalid_limit)
    end

    private

    attr_reader :guardian, :cursor, :limit

    def ranked_candidates(context)
      visible = candidate_scope(context).to_a.select { |video| visible_to_guardian?(video) }
      signals = context.signals(video_ids: visible.map(&:id))

      visible
        .filter_map do |video|
          signal = signals.fetch(video.id)
          next unless signal.qualified_views.positive?

          score = context.score(signal: signal, published_at: video.published_at)

          RankedEntry.new(
            video: video,
            score_basis_points: score.score_basis_points,
            published_microseconds: timestamp_microseconds(video.published_at),
          ).freeze
        end
        .sort_by do |entry|
          [-entry.score_basis_points, -entry.published_microseconds, -entry.video.id]
        end
    end

    def candidate_scope(context)
      Video
        .joins(:topic, :post)
        .includes(:topic, :post, :user)
        .where(status: "published", provider: enabled_providers)
        .where.not(published_at: nil)
        .where("video_hub_videos.published_at <= ?", context.snapshot_at)
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
        .limit(MAX_SCAN_ROWS)
    end

    def enabled_providers
      VideoHub::WatchQuery::PROVIDER_SETTINGS.filter_map do |provider, setting|
        provider if SiteSetting.public_send(setting)
      end
    end

    def visible_to_guardian?(video)
      VideoHub::WatchQuery.visible_video?(video, guardian: guardian)
    end

    def after_cursor?(entry, decoded_cursor)
      return true if entry.score_basis_points < decoded_cursor.score_basis_points
      return false if entry.score_basis_points > decoded_cursor.score_basis_points

      cursor_published_microseconds = timestamp_microseconds(decoded_cursor.published_at)
      return true if entry.published_microseconds < cursor_published_microseconds
      return false if entry.published_microseconds > cursor_published_microseconds

      entry.video.id < decoded_cursor.video_id
    end

    def encode_cursor(context, entry)
      TrendingFeedCursor.encode(
        context: context,
        score_basis_points: entry.score_basis_points,
        published_at: entry.video.published_at,
        video_id: entry.video.id,
      )
    end

    def decode_cursor(value)
      return if value.blank?

      TrendingFeedCursor.decode(value)
    end

    def timestamp_microseconds(value)
      time = value.to_time
      time.to_i * 1_000_000 + time.usec
    end
  end
end
