# frozen_string_literal: true

describe VideoHub::PublishVideo do
  let(:category) { Fabricate(:category) }
  let(:user) { Fabricate(:user, trust_level: 1) }
  let(:input_url) { "https://youtu.be/dQw4w9WgXcQ?t=42" }
  let(:canonical_url) { "https://www.youtube.com/watch?v=dQw4w9WgXcQ" }
  let(:external_id) { "dQw4w9WgXcQ" }
  let(:resolved) do
    VideoHub::ProviderUrlParser::Result.new(
      provider: "youtube",
      external_id: external_id,
      canonical_url: canonical_url,
    ).freeze
  end
  let(:metadata) do
    {
      provider: "youtube",
      external_id: external_id,
      canonical_url: canonical_url,
      kind: "landscape",
      title: "A canonical Video Hub test video",
      description: nil,
      thumbnail_url: "https://i.ytimg.com/vi/#{external_id}/hqdefault.jpg",
      duration_seconds: nil,
      author_name: "Example creator",
    }.freeze
  end

  it "creates one core Topic/root Post and one published Video atomically" do
    stub_authorization
    stub_provider_resolution
    VideoHub::ProviderMetadataFetcher.expects(:fetch).with(canonical_url).returns(metadata)

    video = nil
    expect do
      video = described_class.publish(user: user, url: input_url, caption: "My caption")
    end.to change { VideoHub::Video.count }.by(1).and change { Topic.count }.by(1).and change { Post.count }.by(1)

    expect(video).to be_persisted
    expect(video.status).to eq("published")
    expect(video.provider).to eq("youtube")
    expect(video.external_id).to eq(external_id)
    expect(video.canonical_url).to eq(canonical_url)
    expect(video.user).to eq(user)
    expect(video.topic.category_id).to eq(category.id)
    expect(video.post.topic_id).to eq(video.topic_id)
    expect(video.post.post_number).to eq(1)
    expect(video.post.raw).to eq("My caption\n\n#{canonical_url}")
    expect(video.topic.title).to eq(metadata[:title])
    expect(video.published_at).to be_present
  end

  it "runs base authorization before resolving or fetching any provider URL" do
    VideoHub::PublishPolicy
      .expects(:authorize_base!)
      .with(user: user)
      .raises(VideoHub::PublishPolicy::AuthorizationError.new(:insufficient_trust))
    VideoHub::ProviderUrlResolver.expects(:resolve).never
    VideoHub::ProviderMetadataFetcher.expects(:fetch).never

    expect_publish_error(:insufficient_trust) do
      described_class.publish(user: user, url: input_url)
    end
  end

  it "rejects invalid captions before provider network work" do
    VideoHub::PublishPolicy.expects(:authorize_base!).with(user: user).returns(category)
    VideoHub::ProviderUrlResolver.expects(:resolve).never
    VideoHub::ProviderMetadataFetcher.expects(:fetch).never

    expect_publish_error(:invalid_caption) do
      described_class.publish(user: user, url: input_url, caption: "bad\u0000caption")
    end
  end

  it "checks the resolved provider setting before metadata retrieval" do
    VideoHub::PublishPolicy.expects(:authorize_base!).with(user: user).returns(category)
    VideoHub::ProviderUrlResolver.expects(:resolve).with(input_url).returns(resolved)
    VideoHub::PublishPolicy
      .expects(:authorize_provider!)
      .with(provider: "youtube")
      .raises(VideoHub::PublishPolicy::AuthorizationError.new(:provider_disabled))
    VideoHub::ProviderMetadataFetcher.expects(:fetch).never

    expect_publish_error(:provider_disabled) do
      described_class.publish(user: user, url: input_url)
    end
  end

  it "reuses a visible canonical duplicate without metadata or Topic creation" do
    existing = create_published_video
    stub_authorization
    stub_provider_resolution
    VideoHub::ProviderMetadataFetcher.expects(:fetch).never
    PostCreator.expects(:new).never
    initial_video_count = VideoHub::Video.count
    initial_topic_count = Topic.count
    initial_post_count = Post.count

    result = described_class.publish(user: user, url: input_url)

    expect(result).to eq(existing)
    expect(VideoHub::Video.count).to eq(initial_video_count)
    expect(Topic.count).to eq(initial_topic_count)
    expect(Post.count).to eq(initial_post_count)
  end

  it "does not reveal an existing canonical video when its Topic is not visible" do
    existing = create_published_video
    stub_authorization
    stub_provider_resolution
    VideoHub::ProviderMetadataFetcher.expects(:fetch).never

    guardian = mock
    Guardian.expects(:new).with(user).returns(guardian)
    guardian.expects(:can_see?).with(existing.topic).returns(false)

    expect do
      described_class.publish(user: user, url: input_url)
    end.to raise_error(Discourse::NotFound)
  end

  it "rechecks canonical identity after metadata retrieval so a racing publisher wins cleanly" do
    existing = create_published_video
    stub_authorization
    stub_provider_resolution
    VideoHub::ProviderMetadataFetcher.expects(:fetch).with(canonical_url).returns(metadata)
    VideoHub::Video
      .expects(:find_by)
      .with(provider: "youtube", external_id: external_id)
      .twice
      .returns(nil, existing)
    PostCreator.expects(:new).never
    initial_topic_count = Topic.count
    initial_post_count = Post.count

    result = described_class.publish(user: user, url: input_url)

    expect(result).to eq(existing)
    expect(Topic.count).to eq(initial_topic_count)
    expect(Post.count).to eq(initial_post_count)
  end

  it "rejects metadata whose canonical identity differs from the resolved URL" do
    stub_authorization
    stub_provider_resolution
    mismatched = metadata.merge(external_id: "other-id")
    VideoHub::ProviderMetadataFetcher.expects(:fetch).with(canonical_url).returns(mismatched)
    PostCreator.expects(:new).never

    expect_publish_error(:metadata_identity_mismatch) do
      described_class.publish(user: user, url: input_url)
    end

    expect(VideoHub::Video.where(provider: "youtube", external_id: external_id)).to be_empty
  end

  it "rolls back the core Topic/root Post when Video persistence fails" do
    stub_authorization
    stub_provider_resolution
    VideoHub::ProviderMetadataFetcher.expects(:fetch).with(canonical_url).returns(metadata)
    VideoHub::Video.any_instance.stubs(:save!).raises(
      ActiveRecord::RecordInvalid.new(VideoHub::Video.new),
    )

    initial_video_count = VideoHub::Video.count
    initial_topic_count = Topic.count
    initial_post_count = Post.count

    expect_publish_error(:publish_failed) do
      described_class.publish(user: user, url: input_url, caption: "Rollback me")
    end

    expect(VideoHub::Video.count).to eq(initial_video_count)
    expect(Topic.count).to eq(initial_topic_count)
    expect(Post.count).to eq(initial_post_count)
  end

  it "uses a safe fallback Topic title when provider metadata has no title" do
    stub_authorization
    stub_provider_resolution
    VideoHub::ProviderMetadataFetcher.expects(:fetch).with(canonical_url).returns(
      metadata.merge(title: nil),
    )

    video = described_class.publish(user: user, url: input_url)

    expect(video.topic.title).to include("Youtube video")
    expect(video.topic.title).to include(external_id)
  end

  def stub_authorization
    VideoHub::PublishPolicy.expects(:authorize_base!).with(user: user).returns(category)
    VideoHub::PublishPolicy.expects(:authorize_provider!).with(provider: "youtube").returns("youtube")
  end

  def stub_provider_resolution
    VideoHub::ProviderUrlResolver.expects(:resolve).with(input_url).returns(resolved)
  end

  def create_published_video
    owner = Fabricate(:user)
    topic = Fabricate(:topic, user: owner)
    post = Fabricate(:post, topic: topic, user: owner)

    VideoHub::Video.create!(
      user: owner,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: external_id,
      canonical_url: canonical_url,
      kind: "landscape",
      title: metadata[:title],
      status: "published",
      published_at: Time.zone.now,
    )
  end

  def expect_publish_error(code)
    expect { yield }.to raise_error(described_class::PublishError) do |error|
      expect(error.code).to eq(code)
      expect(error.message).to eq(code.to_s)
    end
  end
end
