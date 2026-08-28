# frozen_string_literal: true

describe VideoHub::WatchQuery do
  before do
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_tiktok_enabled = true
    SiteSetting.video_hub_instagram_enabled = false
  end

  it "returns a published enabled-provider video when its Topic and root Post are visible" do
    video = create_video

    result = described_class.fetch(user: nil, id: video.id.to_s)

    expect(result.video).to eq(video)
    expect(result.slug).to eq(video.topic.slug)
  end

  it "fails closed for invalid or missing identifiers" do
    expect { described_class.fetch(user: nil, id: "not-an-id") }.to raise_error(Discourse::NotFound)
    expect { described_class.fetch(user: nil, id: "0") }.to raise_error(Discourse::NotFound)
    expect { described_class.fetch(user: nil, id: 999_999_999) }.to raise_error(Discourse::NotFound)
    expect {
      described_class.fetch(user: nil, id: described_class::MAX_RECORD_ID + 1)
    }.to raise_error(Discourse::NotFound)
  end

  it "hides non-published videos and videos whose provider is disabled" do
    unavailable = create_video(status: "unavailable")
    instagram = create_video(provider: "instagram")

    expect { described_class.fetch(user: nil, id: unavailable.id) }.to raise_error(
      Discourse::NotFound,
    )
    expect { described_class.fetch(user: nil, id: instagram.id) }.to raise_error(
      Discourse::NotFound,
    )
  end

  it "hides videos whose backing Topic or root Post was deleted" do
    deleted_topic_video = create_video
    deleted_topic_video.topic.update_column(:deleted_at, Time.zone.now)

    deleted_post_video = create_video
    deleted_post_video.post.update_column(:deleted_at, Time.zone.now)

    expect { described_class.fetch(user: nil, id: deleted_topic_video.id) }.to raise_error(
      Discourse::NotFound,
    )
    expect { described_class.fetch(user: nil, id: deleted_post_video.id) }.to raise_error(
      Discourse::NotFound,
    )
  end

  it "requires final Guardian visibility for both the Topic and root Post" do
    video = create_video
    user = Fabricate(:user)
    guardian = mock
    guardian.stubs(:can_see?).with(video.topic).returns(true)
    guardian.stubs(:can_see?).with(video.post).returns(false)
    Guardian.expects(:new).with(user).returns(guardian)

    expect { described_class.fetch(user: user, id: video.id) }.to raise_error(Discourse::NotFound)
  end

  def create_video(provider: "youtube", status: "published")
    @video_sequence = @video_sequence.to_i + 1
    owner = Fabricate(:user)
    topic = Fabricate(:topic, user: owner)
    post = Fabricate(:post, topic: topic, user: owner)
    external_id = "watch-video-#{@video_sequence}"

    VideoHub::Video.create!(
      user: owner,
      topic: topic,
      post: post,
      provider: provider,
      external_id: external_id,
      canonical_url: "https://example.com/#{external_id}",
      kind: "landscape",
      title: "Watch video #{@video_sequence}",
      thumbnail_url: nil,
      duration_seconds: nil,
      author_name: "Watch author",
      status: status,
      published_at: status == "published" ? Time.zone.now : nil,
    )
  end
end
