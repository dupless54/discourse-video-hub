# frozen_string_literal: true

describe VideoHub::FeedQuery do
  let(:category) { Fabricate(:category) }
  let(:now) { Time.zone.parse("2026-08-30 12:00:00") }
  let(:metric_day) { Date.new(2026, 8, 29) }

  before do
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_tiktok_enabled = true
    SiteSetting.video_hub_instagram_enabled = false
    SiteSetting.video_hub_ranking_qualified_rate_weight = 100
    SiteSetting.video_hub_ranking_qualified_volume_weight = 0
    SiteSetting.video_hub_ranking_freshness_weight = 0
  end

  it "ranks bounded visible candidates by score before publication recency" do
    newest_without_signal = create_video(published_at: now - 1.minute)
    newer_low_score = create_video(published_at: now - 2.minutes)
    older_high_score = create_video(published_at: now - 3.minutes)
    create_metric(newer_low_score, impressions: 10, qualified_views: 2)
    create_metric(older_high_score, impressions: 10, qualified_views: 8)

    result = nil
    freeze_time(now) { result = described_class.fetch(user: nil) }

    expect(result.videos.map(&:id)).to eq(
      [older_high_score.id, newer_low_score.id, newest_without_signal.id],
    )
  end

  it "uses publication time and id as deterministic tie breakers across signed cursor pages" do
    published_at = now - 1.hour
    oldest = create_video(published_at: published_at - 1.minute)
    same_time_lower_id = create_video(published_at: published_at)
    same_time_higher_id = create_video(published_at: published_at)

    first_page = nil
    freeze_time(now) { first_page = described_class.fetch(user: nil, limit: 2) }

    expect(first_page.videos.map(&:id)).to eq([same_time_higher_id.id, same_time_lower_id.id])
    expect(first_page.has_more).to eq(true)
    expect(first_page.next_cursor).to be_present

    second_page = nil
    freeze_time(now) do
      second_page = described_class.fetch(user: nil, cursor: first_page.next_cursor, limit: 2)
    end

    expect(second_page.videos.map(&:id)).to eq([oldest.id])
    expect(second_page.has_more).to eq(false)
    expect(second_page.next_cursor).to be_nil
  end

  it "keeps ranking weights and the candidate snapshot stable across pages" do
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

  it "filters non-published records, disabled providers, invisible Topics, and hidden root Posts" do
    visible = create_video(published_at: now - 1.minute)
    create_video(status: "unavailable")
    create_video(provider: "instagram", published_at: now - 2.minutes)

    invisible_topic_video = create_video(published_at: now - 3.minutes)
    invisible_topic_video.topic.update_column(:visible, false)

    hidden_post_video = create_video(published_at: now - 4.minutes)
    hidden_post_video.post.update_column(:hidden, true)

    result = nil
    freeze_time(now) { result = described_class.fetch(user: nil) }

    expect(result.videos).to eq([visible])
  end

  it "filters deleted Topics and deleted root Posts before ranking" do
    visible = create_video(published_at: now - 1.minute)

    deleted_topic_video = create_video(published_at: now - 2.minutes)
    deleted_topic_video.topic.update_column(:deleted_at, now)

    deleted_post_video = create_video(published_at: now - 3.minutes)
    deleted_post_video.post.update_column(:deleted_at, now)

    result = nil
    freeze_time(now) { result = described_class.fetch(user: nil) }

    expect(result.videos).to eq([visible])
  end

  it "applies final Guardian visibility before calculating the ranked page" do
    visible = create_video(published_at: now - 2.minutes)
    hidden_by_guardian = create_video(published_at: now - 1.minute)
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

  it "fails closed on malformed or legacy cursors" do
    %w[not-a-cursor ZmFrZS1sZWdhY3ktY3Vyc29y].each do |cursor|
      expect { described_class.fetch(user: nil, cursor: cursor) }.to raise_error(
        described_class::FeedError,
      ) do |error|
        expect(error.code).to eq(:invalid_cursor)
        expect(error.message).to eq("invalid_cursor")
      end
    end
  end

  it "rejects page sizes above the bounded public maximum" do
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

  def create_video(published_at: now, provider: "youtube", status: "published")
    @video_sequence = @video_sequence.to_i + 1
    external_id = "feed-video-#{@video_sequence}"
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
      title: "Feed video #{@video_sequence}",
      thumbnail_url: nil,
      duration_seconds: nil,
      author_name: "Feed author",
      status: status,
      published_at: status == "published" ? published_at : nil,
    )
  end
end
