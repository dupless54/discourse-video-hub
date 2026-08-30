# frozen_string_literal: true

module VideoHub
  class RankingSignals
    VERSION = 1
    WINDOW_DAYS = 7
    MAX_BATCH_SIZE = 200
    MAX_SIGNAL_COUNT = 10_000
    RATE_BASIS_POINTS = 10_000

    Result =
      Struct.new(
        :version,
        :video_id,
        :impressions,
        :qualified_views,
        :qualified_rate_basis_points,
        keyword_init: true,
      )

    class RankingError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    def self.fetch(video_ids:, as_of: Time.zone.now)
      new(video_ids: video_ids, as_of: as_of).fetch
    end

    def initialize(video_ids:, as_of:)
      @video_ids = Array(video_ids).map { |video_id| Integer(video_id) }.uniq
      @as_of = as_of.to_date
    rescue ArgumentError, TypeError, NoMethodError
      raise RankingError.new(:invalid_input)
    end

    def fetch
      raise RankingError.new(:invalid_video_ids) if video_ids.any? { |video_id| video_id <= 0 }
      raise RankingError.new(:too_many_videos) if video_ids.length > MAX_BATCH_SIZE
      return {}.freeze if video_ids.empty?

      scope = DailyMetric.where(video_id: video_ids, day: window_start_day..as_of)

      impressions_by_video = scope.group(:video_id).sum(:impressions)
      qualified_views_by_video = scope.group(:video_id).sum(:qualified_views)

      video_ids
        .index_with do |video_id|
          impressions = capped_count(impressions_by_video.fetch(video_id, 0))
          qualified_views = [
            capped_count(qualified_views_by_video.fetch(video_id, 0)),
            impressions,
          ].min

          Result.new(
            version: VERSION,
            video_id: video_id,
            impressions: impressions,
            qualified_views: qualified_views,
            qualified_rate_basis_points: rate_basis_points(qualified_views, impressions),
          ).freeze
        end
        .freeze
    end

    private

    attr_reader :video_ids, :as_of

    def window_start_day
      as_of - (WINDOW_DAYS - 1).days
    end

    def capped_count(value)
      [Integer(value), MAX_SIGNAL_COUNT].min
    end

    def rate_basis_points(qualified_views, impressions)
      return 0 if impressions.zero?

      qualified_views * RATE_BASIS_POINTS / impressions
    end
  end
end
