# frozen_string_literal: true

describe VideoHub::FollowingFeedQuery do
  let(:viewer) { Fabricate(:user) }
  let(:followed) { Fabricate(:user) }
  let(:unfollowed) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }
  let(:now) { Time.zone.parse("2026-08-31 08:00:00") }

  before do
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_tiktok_enabled = true
    SiteSetting.video_hub_instagram_enabled = false
    VideoHub::FollowSource
      .stubs(:following_user_ids)
      .with(user: viewer)
      .returns(User.where(id: followed.id).select(:id))
  end

  it "returns only visible videos from followed users in publish order" do
    newest = create_video(owner: followed, published_at: now - 1.minute)
    older = create_video(owner: followed, provider: "tiktok", published_at: now - 2.minutes)
    not_followed = create_video(owner: unfollowed, published_at: now - 30.seconds)
    disabled_provider =
      create_video(owner: followed, provider: "instagram", published_at: now - 3.minutes)
    hidden_post = create_video(owner: followed, published_at: now - 4.minutes)
    hidden_post.post.update_column(:hidden, true)

    result = described_class.fetch(user: viewer)

    expect(result.videos).to eq([newest, older])
    expect(result.videos).not_to include(not_followed, disabled_provider, hidden_post)
    expect(result.has_more).to eq(false)
    expect(result.next_cursor).to be_nil
  end

  it "paginates deterministically with the following-feed cursor" do
    first = create_video(owner: followed, published_at: now - 1.minute)
    second = create_video(owner: followed, published_at: now - 2.minutes)
    third = create_video(owner: followed, published_at: now - 3.minutes)

    first_page = described_class.fetch(user: viewer, limit: 1)

    expect(first_page.videos).to eq([first])
    expect(first_page.has_more).to eq(true)
    expect(first_page.next_cursor).to be_present

    published_after_first_page = create_video(owner: followed, published_at: now + 1.minute)
    second_page = described_class.fetch(user: viewer, cursor: first_page.next_cursor, limit: 1)

    expect(second_page.videos).to eq([second])
    expect(second_page.videos).not_to include(first, published_after_first_page)
    expect(second_page.has_more).to eq(true)
    expect(second_page.next_cursor).to be_present

    third_page = described_class.fetch(user: viewer, cursor: second_page.next_cursor, limit: 1)
    expect(third_page.videos).to eq([third])
  end

  it "applies final Guardian visibility before exposing followed videos" do
    visible = create_video(owner: followed, published_at: now - 2.minutes)
    hidden_by_guardian = create_video(owner: followed, published_at: now - 1.minute)
    guardian = mock
    guardian.stubs(:allowed_category_ids).returns([category.id])
    guardian.stubs(:can_see?).returns(true)
    guardian.stubs(:can_see?).with(hidden_by_guardian.topic).returns(false)
    Guardian.expects(:new).with(viewer).returns(guardian)

    result = described_class.fetch(user: viewer)

    expect(result.videos).to eq([visible])
  end

  it "maps an unavailable official follow source to a feed error" do
    VideoHub::FollowSource
      .stubs(:following_user_ids)
      .with(user: viewer)
      .raises(VideoHub::FollowSource::SourceError.new(:follow_unavailable))

    expect { described_class.fetch(user: viewer) }.to raise_error(
      described_class::FeedError,
    ) do |error|
      expect(error.code).to eq(:follow_unavailable)
    end
  end

  it "rejects anonymous access, foreign cursors, and page sizes above the maximum" do
    expect { described_class.fetch(user: nil) }.to raise_error(
      described_class::FeedError,
    ) do |error|
      expect(error.code).to eq(:login_required)
    end

    saved_cursor = VideoHub::SavedFeedCursor.encode(saved_at: now - 1.minute, bookmark_id: 42)

    expect { described_class.fetch(user: viewer, cursor: saved_cursor) }.to raise_error(
      described_class::FeedError,
    ) { |error| expect(error.code).to eq(:invalid_cursor) }

    expect {
      described_class.fetch(user: viewer, limit: described_class::DEFAULT_LIMIT + 1)
    }.to raise_error(described_class::FeedError) { |error|
      expect(error.code).to eq(:invalid_limit)
    }
  end

  def create_video(owner:, published_at:, provider: "youtube")
    @video_sequence = @video_sequence.to_i + 1
    external_id = "following-video-#{@video_sequence}"
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
      title: "Following video #{@video_sequence}",
      thumbnail_url: nil,
      duration_seconds: nil,
      author_name: "Following author",
      status: "published",
      published_at: published_at,
    )
  end
end
