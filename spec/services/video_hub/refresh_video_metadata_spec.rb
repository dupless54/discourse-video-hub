# frozen_string_literal: true

describe VideoHub::RefreshVideoMetadata do
  let(:owner) { Fabricate(:user) }
  let(:topic) { Fabricate(:topic, user: owner) }
  let(:post) { Fabricate(:post, topic: topic, user: owner) }
  let(:canonical_url) { "https://www.youtube.com/watch?v=refresh123" }
  let(:video) do
    VideoHub::Video.create!(
      user: owner,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: "refresh123",
      canonical_url: canonical_url,
      kind: "landscape",
      title: "Old title",
      description: "Old description",
      status: "published",
      published_at: 3.days.ago,
      metadata_refreshed_at: 2.days.ago,
    )
  end
  let(:metadata) do
    {
      provider: "youtube",
      external_id: "refresh123",
      canonical_url: canonical_url,
      kind: "landscape",
      title: "Fresh title",
      description: "Fresh description",
      thumbnail_url: "https://i.ytimg.com/vi/refresh123/hqdefault.jpg",
      duration_seconds: 42,
      author_name: "Fresh creator",
    }.freeze
  end

  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
    DistributedMutex.stubs(:synchronize).yields
    Rails.logger.stubs(:warn)
  end

  it "refreshes only mutable metadata for a stale published video" do
    original_refreshed_at = video.metadata_refreshed_at
    VideoHub::ProviderMetadataFetcher.expects(:refresh).with(canonical_url).returns(metadata)

    expect(described_class.refresh(video_id: video.id)).to eq(:refreshed)

    video.reload
    expect(video.provider).to eq("youtube")
    expect(video.external_id).to eq("refresh123")
    expect(video.canonical_url).to eq(canonical_url)
    expect(video.kind).to eq("landscape")
    expect(video.title).to eq("Fresh title")
    expect(video.description).to eq("Fresh description")
    expect(video.thumbnail_url).to eq(metadata[:thumbnail_url])
    expect(video.duration_seconds).to eq(42)
    expect(video.author_name).to eq("Fresh creator")
    expect(video.metadata_refreshed_at).to be > original_refreshed_at
  end

  it "does not call a provider while the metadata freshness window is still valid" do
    video.update!(metadata_refreshed_at: 1.hour.ago)
    VideoHub::ProviderMetadataFetcher.expects(:refresh).never

    expect(described_class.refresh(video_id: video.id)).to eq(:fresh)
  end

  it "does not call a disabled provider" do
    video
    SiteSetting.video_hub_youtube_enabled = false
    VideoHub::ProviderMetadataFetcher.expects(:refresh).never

    expect(described_class.refresh(video_id: video.id)).to eq(:ineligible)
  end

  it "fails closed when refreshed metadata changes canonical identity or video kind" do
    original_refreshed_at = video.metadata_refreshed_at
    VideoHub::ProviderMetadataFetcher
      .expects(:refresh)
      .with(canonical_url)
      .returns(metadata.merge(kind: "shorts", title: "Unsafe replacement"))

    expect(described_class.refresh(video_id: video.id)).to eq(:identity_mismatch)

    video.reload
    expect(video.kind).to eq("landscape")
    expect(video.title).to eq("Old title")
    expect(video.metadata_refreshed_at).to be > original_refreshed_at
  end

  it "backs off safely after a provider refresh failure without mutating metadata" do
    original_refreshed_at = video.metadata_refreshed_at
    VideoHub::ProviderMetadataFetcher
      .expects(:refresh)
      .with(canonical_url)
      .raises(VideoHub::ProviderMetadataFetcher::MetadataError.new(:network_error))

    expect(described_class.refresh(video_id: video.id)).to eq(:failed)

    video.reload
    expect(video.title).to eq("Old title")
    expect(video.description).to eq("Old description")
    expect(video.metadata_refreshed_at).to be > original_refreshed_at
  end

  it "is a no-op for missing records" do
    VideoHub::ProviderMetadataFetcher.expects(:refresh).never

    expect(described_class.refresh(video_id: 9_223_372_036_854_775_807)).to eq(:missing)
  end
end
