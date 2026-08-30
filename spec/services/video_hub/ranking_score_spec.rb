# frozen_string_literal: true

describe VideoHub::RankingScore do
  let(:as_of) { Time.zone.parse("2026-08-30 12:00:00") }

  before do
    SiteSetting.video_hub_ranking_qualified_rate_weight = 60
    SiteSetting.video_hub_ranking_qualified_volume_weight = 25
    SiteSetting.video_hub_ranking_freshness_weight = 15
  end

  it "returns a deterministic versioned and explainable weighted score" do
    result =
      described_class.score(
        signal: build_signal(qualified_views: 5_000, qualified_rate_basis_points: 5_000),
        published_at: as_of - 7.days,
        as_of: as_of,
      )

    expect(result.version).to eq(1)
    expect(result.score_basis_points).to eq(5_000)
    expect(result.components).to eq(
      qualified_rate: 5_000,
      qualified_volume: 5_000,
      freshness: 5_000,
    )
    expect(result.weights).to eq(qualified_rate: 60, qualified_volume: 25, freshness: 15)
    expect(result.components).to be_frozen
    expect(result.weights).to be_frozen
    expect(result).to be_frozen
  end

  it "honors admin weights without changing score semantics" do
    SiteSetting.video_hub_ranking_qualified_rate_weight = 100
    SiteSetting.video_hub_ranking_qualified_volume_weight = 0
    SiteSetting.video_hub_ranking_freshness_weight = 0

    result =
      described_class.score(
        signal: build_signal(qualified_views: 10_000, qualified_rate_basis_points: 7_500),
        published_at: as_of,
        as_of: as_of,
      )

    expect(result.score_basis_points).to eq(7_500)
  end

  it "returns zero when staff intentionally disables every ranking weight" do
    SiteSetting.video_hub_ranking_qualified_rate_weight = 0
    SiteSetting.video_hub_ranking_qualified_volume_weight = 0
    SiteSetting.video_hub_ranking_freshness_weight = 0

    result =
      described_class.score(
        signal: build_signal(qualified_views: 10_000, qualified_rate_basis_points: 10_000),
        published_at: as_of,
        as_of: as_of,
      )

    expect(result.score_basis_points).to eq(0)
  end

  it "bounds freshness to the fourteen-day ranking window" do
    SiteSetting.video_hub_ranking_qualified_rate_weight = 0
    SiteSetting.video_hub_ranking_qualified_volume_weight = 0
    SiteSetting.video_hub_ranking_freshness_weight = 100
    signal = build_signal(qualified_views: 0, qualified_rate_basis_points: 0)

    expect(score_for(signal, published_at: as_of)).to eq(10_000)
    expect(score_for(signal, published_at: as_of - 7.days)).to eq(5_000)
    expect(score_for(signal, published_at: as_of - 14.days)).to eq(0)
    expect(score_for(signal, published_at: as_of + 1.hour)).to eq(10_000)
    expect(score_for(signal, published_at: nil)).to eq(0)
  end

  it "fails closed on unsupported or malformed ranking signals" do
    unsupported = build_signal(version: 2)
    invalid = build_signal(qualified_rate_basis_points: 10_001)

    expect { described_class.score(signal: unsupported, published_at: as_of, as_of: as_of) }.to raise_error(
      described_class::RankingError,
    ) { |error| expect(error.code).to eq(:unsupported_signal_version) }

    expect { described_class.score(signal: invalid, published_at: as_of, as_of: as_of) }.to raise_error(
      described_class::RankingError,
    ) { |error| expect(error.code).to eq(:invalid_signal) }

    expect { described_class.score(signal: Object.new, published_at: as_of, as_of: as_of) }.to raise_error(
      described_class::RankingError,
    ) { |error| expect(error.code).to eq(:invalid_input) }
  end

  def score_for(signal, published_at:)
    described_class.score(signal: signal, published_at: published_at, as_of: as_of).score_basis_points
  end

  def build_signal(version: 1, qualified_views: 5_000, qualified_rate_basis_points: 5_000)
    VideoHub::RankingSignals::Result.new(
      version: version,
      video_id: 1,
      impressions: 10_000,
      qualified_views: qualified_views,
      qualified_rate_basis_points: qualified_rate_basis_points,
    ).freeze
  end
end
