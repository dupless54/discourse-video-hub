# frozen_string_literal: true

describe "Video Hub publish metadata refresh scheduling" do
  let(:category) { Fabricate(:category) }
  let(:user) { Fabricate(:user, trust_level: 1) }
  let(:input_url) { "https://youtu.be/publishRefresh123?t=42" }
  let(:canonical_url) { "https://www.youtube.com/watch?v=publishRefresh123" }
  let(:resolved) do
    VideoHub::ProviderUrlParser::Result.new(
      provider: "youtube",
      external_id: "publishRefresh123",
      canonical_url: canonical_url,
    ).freeze
  end
  let(:metadata) do
    {
      provider: "youtube",
      external_id: "publishRefresh123",
      canonical_url: canonical_url,
      kind: "landscape",
      title: "Publish refresh test",
      description: nil,
      thumbnail_url: nil,
      duration_seconds: nil,
      author_name: "Creator",
    }.freeze
  end

  before do
    VideoHub::PublishPolicy.expects(:authorize_base!).with(user: user).returns(category)
    VideoHub::PublishPolicy
      .expects(:authorize_provider!)
      .with(provider: "youtube")
      .returns("youtube")
    VideoHub::ProviderUrlResolver.expects(:resolve).with(input_url).returns(resolved)
    VideoHub::ProviderMetadataFetcher.expects(:fetch).with(canonical_url).returns(metadata)
  end

  it "marks initial metadata fresh and enqueues the first refresh only after persistence" do
    captured = nil
    Jobs
      .stubs(:enqueue_in)
      .with do |delay, job_class, args|
        captured = [delay, job_class, args]
        VideoHub::Video.exists?(id: args[:video_id], status: "published")
      end
      .returns(nil)

    video = VideoHub::PublishVideo.publish(user: user, url: input_url)

    expect(video.metadata_refreshed_at).to be_present
    expect(video.metadata_refreshed_at).to eq(video.published_at)
    expect(captured).to eq(
      [
        VideoHub::RefreshVideoMetadata::STALE_AFTER,
        Jobs::VideoHub::RefreshVideoMetadata,
        { video_id: video.id },
      ],
    )
  end

  it "keeps a committed publish successful when the non-critical enqueue fails" do
    Jobs.stubs(:enqueue_in).raises(StandardError.new("queue unavailable"))
    Rails.logger.stubs(:warn)

    video = VideoHub::PublishVideo.publish(user: user, url: input_url)

    expect(video).to be_persisted
    expect(video.status).to eq("published")
    expect(VideoHub::Video.exists?(video.id)).to eq(true)
  end
end
