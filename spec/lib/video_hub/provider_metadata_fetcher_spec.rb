# frozen_string_literal: true

describe VideoHub::ProviderMetadataFetcher do
  describe ".fetch" do
    it "resolves and dispatches YouTube metadata using only the canonical URL" do
      input = "https://youtu.be/dQw4w9WgXcQ?t=42"
      canonical_url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      metadata = { provider: "youtube", external_id: "dQw4w9WgXcQ" }.freeze

      expect_resolver(input, resolved_result("youtube", "dQw4w9WgXcQ", canonical_url))
      VideoHub::Providers::Youtube.expects(:fetch).with(canonical_url).returns(metadata)
      VideoHub::Providers::Tiktok.expects(:fetch).never
      VideoHub::Providers::Instagram.expects(:fetch).never

      expect(described_class.fetch(input)).to equal(metadata)
    end

    it "uses the resolver seam for TikTok short links before dispatching canonical metadata" do
      input = "https://vm.tiktok.com/ZMexample/"
      canonical_url = "https://www.tiktok.com/@creator/video/6718335390845095173"
      metadata = { provider: "tiktok", external_id: "6718335390845095173" }.freeze

      expect_resolver(input, resolved_result("tiktok", "6718335390845095173", canonical_url))
      VideoHub::Providers::Tiktok.expects(:fetch).with(canonical_url).returns(metadata)
      VideoHub::Providers::Youtube.expects(:fetch).never
      VideoHub::Providers::Instagram.expects(:fetch).never

      expect(described_class.fetch(input)).to equal(metadata)
    end

    it "dispatches Instagram Reel metadata using the resolver-owned canonical URL" do
      input = "https://instagram.com/reel/AbCdEf123/?utm_source=share"
      canonical_url = "https://www.instagram.com/reel/AbCdEf123/"
      metadata = { provider: "instagram", external_id: "AbCdEf123" }.freeze

      expect_resolver(input, resolved_result("instagram", "AbCdEf123", canonical_url))
      VideoHub::Providers::Instagram.expects(:fetch).with(canonical_url).returns(metadata)
      VideoHub::Providers::Youtube.expects(:fetch).never
      VideoHub::Providers::Tiktok.expects(:fetch).never

      expect(described_class.fetch(input)).to equal(metadata)
    end

    it "fails closed when the resolver returns an unknown provider" do
      input = "https://example.test/video/123"
      expect_resolver(input, resolved_result("unknown", "123", "https://example.test/video/123"))
      VideoHub::Providers::Youtube.expects(:fetch).never
      VideoHub::Providers::Tiktok.expects(:fetch).never
      VideoHub::Providers::Instagram.expects(:fetch).never

      expect_metadata_error(input, :unsupported_provider)
    end

    it "maps resolver failures to the stable metadata error contract" do
      input = "https://vm.tiktok.com/ZMexample/"
      VideoHub::ProviderUrlResolver
        .expects(:resolve)
        .with(input)
        .raises(VideoHub::ProviderUrlResolver::ResolveError.new(:unsafe_network_target))

      expect_metadata_error(input, :unsafe_network_target)
    end

    it "maps YouTube adapter failures to the stable metadata error contract" do
      input = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      expect_resolver(
        input,
        resolved_result("youtube", "dQw4w9WgXcQ", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
      )
      VideoHub::Providers::Youtube.expects(:fetch).raises(
        VideoHub::Providers::Youtube::MetadataError.new(:invalid_metadata),
      )

      expect_metadata_error(input, :invalid_metadata)
    end

    it "maps TikTok adapter failures to the stable metadata error contract" do
      input = "https://www.tiktok.com/@creator/video/6718335390845095173"
      expect_resolver(input, resolved_result("tiktok", "6718335390845095173", input))
      VideoHub::Providers::Tiktok.expects(:fetch).raises(
        VideoHub::Providers::Tiktok::MetadataError.new(:network_error),
      )

      expect_metadata_error(input, :network_error)
    end

    it "maps Instagram adapter failures to the stable metadata error contract" do
      input = "https://www.instagram.com/reel/AbCdEf123/"
      expect_resolver(input, resolved_result("instagram", "AbCdEf123", input))
      VideoHub::Providers::Instagram.expects(:fetch).raises(
        VideoHub::Providers::Instagram::MetadataError.new(:unsupported_source),
      )

      expect_metadata_error(input, :unsupported_source)
    end
  end

  def expect_resolver(input, result)
    VideoHub::ProviderUrlResolver.expects(:resolve).with(input).returns(result)
  end

  def resolved_result(provider, external_id, canonical_url)
    VideoHub::ProviderUrlParser::Result.new(
      provider: provider,
      external_id: external_id,
      canonical_url: canonical_url,
    ).freeze
  end

  def expect_metadata_error(input, code)
    expect { described_class.fetch(input) }.to raise_error(
      described_class::MetadataError,
    ) do |error|
      expect(error.code).to eq(code)
      expect(error.message).to eq(code.to_s)
    end
  end
end
