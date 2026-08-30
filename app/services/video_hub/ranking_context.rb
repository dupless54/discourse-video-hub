# frozen_string_literal: true

module VideoHub
  class RankingContext
    VERSION = 1

    class ContextError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    attr_reader :version, :snapshot_at, :metric_as_of, :weights

    def self.capture(now: Time.zone.now)
      new(now: now).freeze
    end

    def initialize(now:)
      @version = VERSION
      @snapshot_at = now.to_time.utc
      @metric_as_of = snapshot_at.to_date - 1.day
      @weights = RankingScore.current_weights
    rescue ArgumentError, TypeError, NoMethodError
      raise ContextError.new(:invalid_time)
    end

    def signals(video_ids:)
      RankingSignals.fetch(video_ids: video_ids, as_of: metric_as_of)
    end

    def score(signal:, published_at:)
      RankingScore.score(
        signal: signal,
        published_at: published_at,
        as_of: snapshot_at,
        weights: weights,
      )
    end
  end
end
