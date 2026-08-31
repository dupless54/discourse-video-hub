# frozen_string_literal: true

module VideoHub
  class RankingScore
    VERSION = 1
    MAX_BASIS_POINTS = 10_000
    MAX_WEIGHT = 100
    FRESHNESS_WINDOW_DAYS = 14

    WEIGHT_SETTINGS = {
      qualified_rate: :video_hub_ranking_qualified_rate_weight,
      qualified_volume: :video_hub_ranking_qualified_volume_weight,
      freshness: :video_hub_ranking_freshness_weight,
    }.freeze

    Result = Struct.new(:version, :score_basis_points, :components, :weights, keyword_init: true)

    class RankingError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    def self.score(signal:, published_at:, as_of: Time.zone.now)
      new(signal: signal, published_at: published_at, as_of: as_of).score
    end

    def initialize(signal:, published_at:, as_of:)
      @signal_version = Integer(signal.version)
      @qualified_views = Integer(signal.qualified_views)
      @qualified_rate_basis_points = Integer(signal.qualified_rate_basis_points)
      @published_at = published_at&.to_time
      @as_of = as_of.to_time
    rescue ArgumentError, TypeError, NoMethodError
      raise RankingError.new(:invalid_input)
    end

    def score
      validate_signal!

      components = {
        qualified_rate: qualified_rate_basis_points,
        qualified_volume: qualified_volume_basis_points,
        freshness: freshness_basis_points,
      }.freeze
      weights = configured_weights.freeze
      total_weight = weights.values.sum
      score_basis_points =
        if total_weight.zero?
          0
        else
          components.sum { |name, value| value * weights.fetch(name) } / total_weight
        end

      Result.new(
        version: VERSION,
        score_basis_points: score_basis_points,
        components: components,
        weights: weights,
      ).freeze
    end

    private

    attr_reader :signal_version,
                :qualified_views,
                :qualified_rate_basis_points,
                :published_at,
                :as_of

    def validate_signal!
      unless signal_version == RankingSignals::VERSION
        raise RankingError.new(:unsupported_signal_version)
      end
      unless qualified_views.between?(0, RankingSignals::MAX_SIGNAL_COUNT) &&
               qualified_rate_basis_points.between?(0, MAX_BASIS_POINTS)
        raise RankingError.new(:invalid_signal)
      end
    end

    def qualified_volume_basis_points
      qualified_views * MAX_BASIS_POINTS / RankingSignals::MAX_SIGNAL_COUNT
    end

    def freshness_basis_points
      return 0 unless published_at

      age_seconds = [as_of.to_i - published_at.to_i, 0].max
      window_seconds = FRESHNESS_WINDOW_DAYS.days.to_i
      return 0 if age_seconds >= window_seconds

      (window_seconds - age_seconds) * MAX_BASIS_POINTS / window_seconds
    end

    def configured_weights
      WEIGHT_SETTINGS.transform_values do |setting|
        weight = Integer(SiteSetting.public_send(setting))
        raise RankingError.new(:invalid_weights) unless weight.between?(0, MAX_WEIGHT)

        weight
      end
    rescue ArgumentError, TypeError
      raise RankingError.new(:invalid_weights)
    end
  end
end
