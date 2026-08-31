# frozen_string_literal: true

describe VideoHub::TrendingFeedCursor do
  let(:now) { Time.zone.parse("2026-08-31 12:00:00") }
  let(:context) { VideoHub::RankingContext.capture(now: now) }
  let(:published_at) { now - 2.hours }

  before do
    SiteSetting.video_hub_ranking_qualified_rate_weight = 100
    SiteSetting.video_hub_ranking_qualified_volume_weight = 0
    SiteSetting.video_hub_ranking_freshness_weight = 0
  end

  it "round trips a frozen ranking boundary" do
    token =
      described_class.encode(
        context: context,
        score_basis_points: 7_500,
        published_at: published_at,
        video_id: 42,
      )
    decoded = described_class.decode(token)

    expect(decoded.context.snapshot_at).to eq_time(context.snapshot_at)
    expect(decoded.context.metric_as_of).to eq(context.metric_as_of)
    expect(decoded.context.weights).to eq(context.weights)
    expect(decoded.score_basis_points).to eq(7_500)
    expect(decoded.published_at).to eq_time(published_at)
    expect(decoded.video_id).to eq(42)
  end

  it "rejects a discovery ranking cursor without trending domain separation" do
    ranking_token =
      VideoHub::RankingCursor.encode(
        context: context,
        score_basis_points: 5_000,
        published_at: published_at,
        video_id: 42,
      )

    expect { described_class.decode(ranking_token) }.to raise_error(
      described_class::CursorError,
    )
  end

  it "rejects tampered and malformed tokens" do
    token =
      described_class.encode(
        context: context,
        score_basis_points: 5_000,
        published_at: published_at,
        video_id: 42,
      )
    replacement = token.end_with?("a") ? "b" : "a"
    tampered = "#{token[0...-1]}#{replacement}"

    [tampered, "bad cursor", "x" * (described_class::MAX_LENGTH + 1)].each do |value|
      expect { described_class.decode(value) }.to raise_error(described_class::CursorError)
    end
  end
end
