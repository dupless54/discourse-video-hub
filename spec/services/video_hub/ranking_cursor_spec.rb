# frozen_string_literal: true

describe VideoHub::RankingCursor do
  let(:now) { Time.zone.parse("2026-08-30 12:00:00.123456") }
  let(:published_at) { Time.zone.parse("2026-08-28 08:15:30.654321") }

  before do
    SiteSetting.video_hub_ranking_qualified_rate_weight = 60
    SiteSetting.video_hub_ranking_qualified_volume_weight = 25
    SiteSetting.video_hub_ranking_freshness_weight = 15
  end

  it "round-trips a frozen ranking context and deterministic rank position" do
    context = VideoHub::RankingContext.capture(now: now)
    token =
      described_class.encode(
        context: context,
        score_basis_points: 7_654,
        published_at: published_at,
        video_id: 42,
      )

    decoded = described_class.decode(token)

    expect(token.bytesize).to be <= described_class::MAX_LENGTH
    expect(decoded.context.version).to eq(VideoHub::RankingContext::VERSION)
    expect(decoded.context.snapshot_at).to eq_time(now.utc)
    expect(decoded.context.metric_as_of).to eq(Date.new(2026, 8, 29))
    expect(decoded.context.weights).to eq(qualified_rate: 60, qualified_volume: 25, freshness: 15)
    expect(decoded.score_basis_points).to eq(7_654)
    expect(decoded.published_at).to eq_time(published_at.utc)
    expect(decoded.video_id).to eq(42)
    expect(decoded).to be_frozen
  end

  it "rejects tampered and malformed cursor tokens" do
    context = VideoHub::RankingContext.capture(now: now)
    token =
      described_class.encode(
        context: context,
        score_basis_points: 1_000,
        published_at: published_at,
        video_id: 1,
      )
    tampered = token.dup
    tampered[-1] = tampered[-1] == "a" ? "b" : "a"

    [tampered, "not-a-cursor", "x" * (described_class::MAX_LENGTH + 1)].each do |value|
      expect { described_class.decode(value) }.to raise_error(described_class::CursorError) { |error|
        expect(error.code).to eq(:invalid_cursor)
      }
    end
  end

  it "expires cursor context after the bounded pagination window" do
    context = VideoHub::RankingContext.capture(now: now)
    token = nil

    freeze_time(now) do
      token =
        described_class.encode(
          context: context,
          score_basis_points: 5_000,
          published_at: published_at,
          video_id: 7,
        )
    end

    freeze_time(now + described_class::TTL + 1.second) do
      expect { described_class.decode(token) }.to raise_error(described_class::CursorError) { |error|
        expect(error.code).to eq(:invalid_cursor)
      }
    end
  end

  it "rejects invalid rank positions before creating a token" do
    context = VideoHub::RankingContext.capture(now: now)

    expect {
      described_class.encode(
        context: context,
        score_basis_points: VideoHub::RankingScore::MAX_BASIS_POINTS + 1,
        published_at: published_at,
        video_id: 1,
      )
    }.to raise_error(described_class::CursorError) { |error|
      expect(error.code).to eq(:invalid_cursor)
    }

    expect {
      described_class.encode(
        context: context,
        score_basis_points: 1,
        published_at: published_at,
        video_id: 0,
      )
    }.to raise_error(described_class::CursorError) { |error|
      expect(error.code).to eq(:invalid_cursor)
    }
  end
end
