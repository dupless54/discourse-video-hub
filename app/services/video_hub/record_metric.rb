# frozen_string_literal: true

module VideoHub
  class RecordMetric
    EVENT_COLUMNS = {
      "impression" => :impressions,
      "qualified_view" => :qualified_views,
    }.freeze
    EVENT_MAX_LENGTH = 32
    DEDUPE_TTL = 2.days.to_i
    QUALIFIED_AFTER = 3.seconds.to_i
    RATE_LIMIT_COUNT = 120
    RATE_LIMIT_PERIOD = 1.minute

    class MetricError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    def self.record(user:, video_id:, event:)
      new(user:, video_id:, event:).record
    end

    def initialize(user:, video_id:, event:)
      @user = user
      @video_id = video_id
      @event = event
    end

    def record
      raise Discourse::InvalidAccess unless user
      raise Discourse::NotFound unless SiteSetting.video_hub_enabled

      normalized_event = normalize_event
      video = VideoHub::WatchQuery.fetch(user:, id: video_id).video
      return :ignored if video.user_id == user.id

      RateLimiter.new(user, "video_hub_metric", RATE_LIMIT_COUNT, RATE_LIMIT_PERIOD).performed!

      day = Time.zone.today
      if normalized_event == "qualified_view" && !qualified_impression_ready?(video, day)
        return :ignored
      end

      key = dedupe_key(normalized_event, video, day)
      value = normalized_event == "impression" ? Time.zone.now.to_i.to_s : "1"
      return :duplicate unless Discourse.redis.set(key, value, nx: true, ex: DEDUPE_TTL)

      begin
        increment_daily_metric(video:, day:, event: normalized_event)
      rescue StandardError
        Discourse.redis.del(key)
        raise
      end

      :recorded
    end

    private

    attr_reader :user, :video_id, :event

    def normalize_event
      unless event.is_a?(String) && event.length <= EVENT_MAX_LENGTH && EVENT_COLUMNS.key?(event)
        raise MetricError.new(:invalid_event)
      end

      event
    end

    def qualified_impression_ready?(video, day)
      raw_started_at = Discourse.redis.get(dedupe_key("impression", video, day))
      started_at = Integer(raw_started_at, exception: false)

      started_at && Time.zone.now.to_i - started_at >= QUALIFIED_AFTER
    end

    def dedupe_key(event_name, video, day)
      "video_hub:metric:#{day.iso8601}:#{event_name}:#{video.id}:#{user.id}"
    end

    def increment_daily_metric(video:, day:, event:)
      impressions = event == "impression" ? 1 : 0
      qualified_views = event == "qualified_view" ? 1 : 0

      DB.exec(
        <<~SQL,
          INSERT INTO video_hub_daily_metrics
            (video_id, day, impressions, qualified_views, created_at, updated_at)
          VALUES
            (:video_id, :day, :impressions, :qualified_views, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
          ON CONFLICT (video_id, day) DO UPDATE
          SET impressions = video_hub_daily_metrics.impressions + EXCLUDED.impressions,
              qualified_views = video_hub_daily_metrics.qualified_views + EXCLUDED.qualified_views,
              updated_at = CURRENT_TIMESTAMP
        SQL
        video_id: video.id,
        day: day,
        impressions: impressions,
        qualified_views: qualified_views,
      )
    end
  end
end
