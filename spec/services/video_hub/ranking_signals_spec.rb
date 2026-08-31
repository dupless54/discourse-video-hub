# frozen_string_literal: true

describe VideoHub::RankingSignals do
  let(:as_of) { Date.new(2026, 8, 30) }
  let(:first_video) { create_published_video }
  let(:second_video) { create_published_video }

  it "returns deterministic versioned seven-day aggregate signals and zero-fills missing videos" do
    create_metric(first_video, as_of, impressions: 8, qualified_views: 4)
    create_metric(first_video, as_of - 6.days, impressions: 2, qualified_views: 1)
    create_metric(first_video, as_of - 7.days, impressions: 100, qualified_views: 100)

    results = described_class.fetch(video_ids: [first_video.id, second_video.id], as_of: as_of)

    first = results.fetch(first_video.id)
    expect(first.version).to eq(1)
    expect(first.video_id).to eq(first_video.id)
    expect(first.impressions).to eq(10)
    expect(first.qualified_views).to eq(5)
    expect(first.qualified_rate_basis_points).to eq(5_000)
    expect(first).to be_frozen

    second = results.fetch(second_video.id)
    expect(second.impressions).to eq(0)
    expect(second.qualified_views).to eq(0)
    expect(second.qualified_rate_basis_points).to eq(0)
    expect(results).to be_frozen
  end

  it "caps aggregate signal volume before deriving the qualified rate" do
    create_metric(
      first_video,
      as_of,
      impressions: described_class::MAX_SIGNAL_COUNT + 5_000,
      qualified_views: described_class::MAX_SIGNAL_COUNT + 5_000,
    )

    result = described_class.fetch(video_ids: [first_video.id], as_of: as_of).fetch(first_video.id)

    expect(result.impressions).to eq(described_class::MAX_SIGNAL_COUNT)
    expect(result.qualified_views).to eq(described_class::MAX_SIGNAL_COUNT)
    expect(result.qualified_rate_basis_points).to eq(10_000)
  end

  it "deduplicates requested ids and rejects invalid or oversized batches" do
    duplicate_results =
      described_class.fetch(video_ids: [first_video.id, first_video.id], as_of: as_of)
    expect(duplicate_results.keys).to eq([first_video.id])

    expect { described_class.fetch(video_ids: [0], as_of: as_of) }.to raise_error(
      described_class::RankingError,
    ) { |error| expect(error.code).to eq(:invalid_video_ids) }

    expect {
      described_class.fetch(
        video_ids: Array.new(described_class::MAX_BATCH_SIZE + 1) { |index| index + 1 },
        as_of: as_of,
      )
    }.to raise_error(described_class::RankingError) { |error|
      expect(error.code).to eq(:too_many_videos)
    }
  end

  it "fails closed on malformed ids or ranking dates" do
    expect { described_class.fetch(video_ids: ["not-an-id"], as_of: as_of) }.to raise_error(
      described_class::RankingError,
    ) { |error| expect(error.code).to eq(:invalid_input) }

    expect { described_class.fetch(video_ids: [first_video.id], as_of: Object.new) }.to raise_error(
      described_class::RankingError,
    ) { |error| expect(error.code).to eq(:invalid_input) }
  end

  def create_metric(video, day, impressions:, qualified_views:)
    VideoHub::DailyMetric.create!(
      video: video,
      day: day,
      impressions: impressions,
      qualified_views: qualified_views,
    )
  end

  def create_published_video
    owner = Fabricate(:user)
    topic = Fabricate(:topic, user: owner)
    post = Fabricate(:post, topic: topic, user: owner)
    external_id = SecureRandom.hex(8)

    VideoHub::Video.create!(
      user: owner,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: external_id,
      canonical_url: "https://www.youtube.com/watch?v=#{external_id}",
      kind: "landscape",
      status: "published",
      published_at: Time.zone.now,
    )
  end
end
