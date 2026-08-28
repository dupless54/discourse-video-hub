# frozen_string_literal: true

describe VideoHub::FeedQuery do
  let(:category) { Fabricate(:category) }

  before do
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_tiktok_enabled = true
    SiteSetting.video_hub_instagram_enabled = false
  end

  it "returns published visible videos newest first with a stable keyset cursor" do
    published_at = 1.hour.ago.change(usec: 123_456)
    oldest = create_video(published_at: published_at - 1.minute)
    same_time_lower_id = create_video(published_at: published_at)
    same_time_higher_id = create_video(published_at: published_at)

    first_page = described_class.fetch(user: nil, limit: 2)

    expect(first_page.videos.map(&:id)).to eq([same_time_higher_id.id, same_time_lower_id.id])
    expect(first_page.has_more).to eq(true)
    expect(first_page.next_cursor).to be_present

    second_page = described_class.fetch(user: nil, cursor: first_page.next_cursor, limit: 2)

    expect(second_page.videos.map(&:id)).to eq([oldest.id])
    expect(second_page.has_more).to eq(false)
    expect(second_page.next_cursor).to be_nil
  end

  it "filters non-published records, disabled providers, invisible Topics, and hidden root Posts" do
    visible = create_video
    create_video(status: "unavailable")
    create_video(provider: "instagram")

    invisible_topic_video = create_video
    invisible_topic_video.topic.update_column(:visible, false)

    hidden_post_video = create_video
    hidden_post_video.post.update_column(:hidden, true)

    result = described_class.fetch(user: nil)

    expect(result.videos).to eq([visible])
  end

  it "filters deleted Topics and deleted root Posts before serialization" do
    visible = create_video

    deleted_topic_video = create_video
    deleted_topic_video.topic.update_column(:deleted_at, Time.zone.now)

    deleted_post_video = create_video
    deleted_post_video.post.update_column(:deleted_at, Time.zone.now)

    result = described_class.fetch(user: nil)

    expect(result.videos).to eq([visible])
  end

  it "applies final Guardian visibility after database candidate filtering" do
    visible = create_video
    hidden_by_guardian = create_video
    guardian = mock
    guardian.stubs(:allowed_category_ids).returns([category.id])
    guardian.stubs(:can_see?).returns(true)
    guardian.stubs(:can_see?).with(hidden_by_guardian.topic).returns(false)
    Guardian.expects(:new).with(nil).returns(guardian)

    result = described_class.fetch(user: nil)

    expect(result.videos).to eq([visible])
  end

  it "continues past filtered candidates without losing the next visible page" do
    newest = create_video(published_at: 1.minute.ago)
    filtered = create_video(published_at: 2.minutes.ago)
    oldest = create_video(published_at: 3.minutes.ago)
    filtered.topic.update_column(:visible, false)

    first_page = described_class.fetch(user: nil, limit: 1)
    second_page = described_class.fetch(user: nil, cursor: first_page.next_cursor, limit: 1)

    expect(first_page.videos).to eq([newest])
    expect(first_page.has_more).to eq(true)
    expect(second_page.videos).to eq([oldest])
  end

  it "fails closed on malformed cursors" do
    expect { described_class.fetch(user: nil, cursor: "not-a-cursor") }.to raise_error(
      described_class::FeedError,
    ) do |error|
      expect(error.code).to eq(:invalid_cursor)
      expect(error.message).to eq("invalid_cursor")
    end
  end

  it "rejects page sizes above the bounded public maximum" do
    expect { described_class.fetch(user: nil, limit: described_class::DEFAULT_LIMIT + 1) }.to raise_error(
      described_class::FeedError,
    ) { |error| expect(error.code).to eq(:invalid_limit) }
  end

  def create_video(published_at: Time.zone.now, provider: "youtube", status: "published")
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
