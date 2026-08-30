# frozen_string_literal: true

describe "Video Hub provider metadata refresh cache" do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:input) { "https://www.youtube.com/watch?v=refreshCache123" }
  let(:resolved) do
    VideoHub::ProviderUrlParser::Result.new(
      provider: "youtube",
      external_id: "refreshCache123",
      canonical_url: input,
    ).freeze
  end

  before { Discourse.stubs(:cache).returns(cache) }

  it "bypasses a success cache during refresh and replaces it with fresh normalized metadata" do
    old_metadata = metadata("Old title")
    fresh_metadata = metadata("Fresh title")

    VideoHub::ProviderUrlResolver.expects(:resolve).with(input).times(3).returns(resolved)
    VideoHub::Providers::Youtube
      .expects(:fetch)
      .with(input)
      .twice
      .returns(old_metadata, fresh_metadata)

    expect(VideoHub::ProviderMetadataFetcher.fetch(input)).to eq(old_metadata)
    expect(VideoHub::ProviderMetadataFetcher.refresh(input)).to eq(fresh_metadata)
    expect(VideoHub::ProviderMetadataFetcher.fetch(input)).to eq(fresh_metadata)
  end

  it "respects the short negative cache during refresh to avoid hammering a failing provider" do
    VideoHub::ProviderUrlResolver.expects(:resolve).with(input).twice.returns(resolved)
    VideoHub::Providers::Youtube
      .expects(:fetch)
      .with(input)
      .once
      .raises(VideoHub::Providers::Youtube::MetadataError.new(:network_error))

    expect_metadata_error { VideoHub::ProviderMetadataFetcher.fetch(input) }
    expect_metadata_error { VideoHub::ProviderMetadataFetcher.refresh(input) }
  end

  def metadata(title)
    {
      provider: "youtube",
      external_id: "refreshCache123",
      canonical_url: input,
      kind: "landscape",
      title: title,
      description: nil,
      thumbnail_url: nil,
      duration_seconds: nil,
      author_name: "Creator",
    }.freeze
  end

  def expect_metadata_error(&block)
    expect(&block).to raise_error(VideoHub::ProviderMetadataFetcher::MetadataError) do |error|
      expect(error.code).to eq(:network_error)
    end
  end
end
