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

    def self.restore(snapshot_at:, metric_as_of:, weights:, version: VERSION)
      raise ContextError.new(:unsupported_version) unless Integer(version) == VERSION

      new(now: snapshot_at, metric_as_of: metric_as_of, weights: weights).freeze
    rescue ArgumentError, TypeError
      raise ContextError.new(:unsupported_version)
    end

    def initialize(now:, metric_as_of: nil, weights: nil)
      normalized_time = normalize_time(now)

      @version = VERSION
      @snapshot_at = normalized_time.utc
      @metric_as_of =
        metric_as_of.nil? ? normalized_time.in_time_zone(Time.zone).to_date - 1.day : normalize_date(metric_as_of)
      @weights = weights.nil? ? RankingScore.current_weights : RankingScore.normalize_weights(weights)
    rescue RankingScore::RankingError => error
      raise ContextError.new(error.code)
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

    private

    def normalize_time(value)
      value.to_time
    rescue ArgumentError, TypeError, NoMethodError
      raise ContextError.new(:invalid_time)
    end

    def normalize_date(value)
      return value if value.is_a?(Date)

      Date.iso8601(value.to_s)
    rescue ArgumentError, TypeError
      raise ContextError.new(:invalid_metric_day)
    end
  end
end
