# frozen_string_literal: true

describe VideoHub::RankingContext do
  let(:now) { Time.zone.parse("2026-08-30 12:00:00") }

  before do
    SiteSetting.video_hub_ranking_qualified_rate_weight = 100
    SiteSetting.video_hub_ranking_qualified_volume_weight = 0
    SiteSetting.video_hub_ranking_freshness_weight = 0
  end

  it "freezes server time, the completed metric day, ranking versions, and admin weights" do
    context = described_class.capture(now: now)

    expect(context.version).to eq(1)
    expect(context.snapshot_at).to eq(now.utc)
    expect(context.metric_as_of).to eq(Date.new(2026, 8, 29))
    expect(context.weights).to eq(qualified_rate: 100, qualified_volume: 0, freshness: 0)
    expect(context.weights).to be_frozen
    expect(context).to be_frozen
  end

  it "reads only completed daily aggregates and excludes the mutable current day" do
    video = create_published_video
    create_metric(video, Date.new(2026, 8, 29), impressions: 10, qualified_views: 5)
    create_metric(video, Date.new(2026, 8, 30), impressions: 100, qualified_views: 100)

    signal = described_class.capture(now: now).signals(video_ids: [video.id]).fetch(video.id)

    expect(signal.impressions).to eq(10)
    expect(signal.qualified_views).to eq(5)
    expect(signal.qualified_rate_basis_points).to eq(5_000)
  end

  it "keeps the captured ranking weights stable after SiteSetting changes" do
    context = described_class.capture(now: now)
    SiteSetting.video_hub_ranking_qualified_rate_weight = 0
    SiteSetting.video_hub_ranking_qualified_volume_weight = 100

    result =
      context.score(
        signal: build_signal(qualified_views: 0, qualified_rate_basis_points: 10_000),
        published_at: now - 14.days,
      )

    expect(result.weights).to eq(qualified_rate: 100, qualified_volume: 0, freshness: 0)
    expect(result.score_basis_points).to eq(10_000)
  end

  it "fails closed when the capture time cannot be normalized" do
    expect { described_class.capture(now: Object.new) }.to raise_error(
      described_class::ContextError,
    ) { |error| expect(error.code).to eq(:invalid_time) }
  end

  def build_signal(qualified_views:, qualified_rate_basis_points:)
    VideoHub::RankingSignals::Result.new(
      version: VideoHub::RankingSignals::VERSION,
      video_id: 1,
      impressions: 10_000,
      qualified_views: qualified_views,
      qualified_rate_basis_points: qualified_rate_basis_points,
    ).freeze
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
      published_at: now - 1.day,
    )
  end
end
