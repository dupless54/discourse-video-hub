# frozen_string_literal: true

describe VideoHub::TrendingFeedQuery do
  let(:category) { Fabricate(:category) }
  let(:now) { Time.zone.parse("2026-08-31 12:00:00") }
  let(:metric_day) { Date.new(2026, 8, 30) }

  before do
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_tiktok_enabled = true
    SiteSetting.video_hub_instagram_enabled = false
    SiteSetting.video_hub_ranking_qualified_rate_weight = 100
    SiteSetting.video_hub_ranking_qualified_volume_weight = 0
    SiteSetting.video_hub_ranking_freshness_weight = 0
  end

  it "includes only visible videos with qualified activity in the ranking window" do
    trending = create_video(published_at: now - 2.minutes)
    impression_only = create_video(published_at: now - 1.minute)
    no_signal = create_video(published_at: now - 30.seconds)
    disabled_provider = create_video(provider: "instagram", published_at: now - 3.minutes)
    hidden_post = create_video(published_at: now - 4.minutes)
    hidden_post.post.update_column(:hidden, true)

    create_metric(trending, impressions: 10, qualified_views: 5)
    create_metric(impression_only, impressions: 10, qualified_views: 0)
    create_metric(disabled_provider, impressions: 10, qualified_views: 10)
    create_metric(hidden_post, impressions: 10, qualified_views: 10)

    result = nil
    freeze_time(now) { result = described_class.fetch(user: nil) }

    expect(result.videos).to eq([trending])
    expect(result.videos).not_to include(impression_only, no_signal, disabled_provider, hidden_post)
  end

  it "orders qualified videos by the existing versioned ranking score" do
    newest_low_score = create_video(published_at: now - 1.minute)
    older_high_score = create_video(published_at: now - 10.minutes)
    create_metric(newest_low_score, impressions: 10, qualified_views: 2)
    create_metric(older_high_score, impressions: 10, qualified_views: 8)

    result = nil
    freeze_time(now) { result = described_class.fetch(user: nil) }

    expect(result.videos).to eq([older_high_score, newest_low_score])
  end

  it "keeps the ranking context stable across opaque cursor pages" do
    first = create_video(published_at: now - 3.days)
    expected_second = create_video(published_at: now - 2.days)
    freshness_favorite = create_video(published_at: now - 1.minute)
    create_metric(first, impressions: 10, qualified_views: 9)
    create_metric(expected_second, impressions: 10, qualified_views: 5)
    create_metric(freshness_favorite, impressions: 10, qualified_views: 1)

    first_page = nil
    freeze_time(now) { first_page = described_class.fetch(user: nil, limit: 1) }

    expect(first_page.videos).to eq([first])
    expect(first_page.has_more).to eq(true)
    expect(first_page.next_cursor).to be_present

    SiteSetting.video_hub_ranking_qualified_rate_weight = 0
    SiteSetting.video_hub_ranking_freshness_weight = 100
    published_after_snapshot = create_video(published_at: now + 1.second)
    create_metric(published_after_snapshot, impressions: 10, qualified_views: 10)

    second_page = nil
    freeze_time(now + 10.minutes) do
      second_page = described_class.fetch(user: nil, cursor: first_page.next_cursor, limit: 10)
    end

    expect(second_page.videos).to eq([expected_second, freshness_favorite])
    expect(second_page.videos).not_to include(published_after_snapshot)
  end

  it "applies final Guardian visibility before exposing trending videos" do
    visible = create_video(published_at: now - 2.minutes)
    hidden_by_guardian = create_video(published_at: now - 1.minute)
    create_metric(visible, impressions: 10, qualified_views: 5)
    create_metric(hidden_by_guardian, impressions: 10, qualified_views: 10)
    guardian = mock
    guardian.stubs(:allowed_category_ids).returns([category.id])
    guardian.stubs(:can_see?).returns(true)
    guardian.stubs(:can_see?).with(hidden_by_guardian.topic).returns(false)
    Guardian.expects(:new).with(nil).returns(guardian)

    result = nil
    freeze_time(now) { result = described_class.fetch(user: nil) }

    expect(result.videos).to eq([visible])
  end

  it "rejects discovery cursors and page sizes above the bounded maximum" do
    context = VideoHub::RankingContext.capture(now: now)
    discovery_cursor =
      VideoHub::RankingCursor.encode(
        context: context,
        score_basis_points: 5_000,
        published_at: now - 1.hour,
        video_id: 42,
      )

    expect { described_class.fetch(user: nil, cursor: discovery_cursor) }.to raise_error(
      described_class::FeedError,
    ) { |error| expect(error.code).to eq(:invalid_cursor) }

    expect {
      described_class.fetch(user: nil, limit: described_class::DEFAULT_LIMIT + 1)
    }.to raise_error(described_class::FeedError) { |error|
      expect(error.code).to eq(:invalid_limit)
    }
  end

  def create_metric(video, impressions:, qualified_views:)
    VideoHub::DailyMetric.create!(
      video: video,
      day: metric_day,
      impressions: impressions,
      qualified_views: qualified_views,
    )
  end

  def create_video(published_at: now, provider: "youtube")
    @video_sequence = @video_sequence.to_i + 1
    external_id = "trending-video-#{@video_sequence}"
    owner = Fabricate(:user)
    topic = Fabricate(:topic, user: owner, category: category)
    post = Fabricate(:post, topic: topic, user: owner)

    VideoHub::Video.create!(
      user: owner,
      topic: topic,
      post: post,
      provider: provider,
      external_id: external_id,
      canonical_url: "https://example.com/#{external_id}",
      kind: "landscape",
      title: "Trending video #{@video_sequence}",
      thumbnail_url: nil,
      duration_seconds: nil,
      author_name: "Trending author",
      status: "published",
      published_at: published_at,
    )
  end
end
