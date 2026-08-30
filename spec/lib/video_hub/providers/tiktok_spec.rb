# frozen_string_literal: true

describe VideoHub::Providers::Tiktok do
  describe ".fetch" do
    it "fetches normalized metadata through the fixed TikTok oEmbed endpoint" do
      VideoHub::ProviderJsonFetcher
        .expects(:fetch)
        .with do |url, allowed_hosts:|
          uri = URI.parse(url)
          query = URI.decode_www_form(uri.query).to_h

          uri.scheme == "https" && uri.host == "www.tiktok.com" && uri.port == 443 &&
            uri.path == "/oembed" && allowed_hosts == ["www.tiktok.com"] &&
            query == { "url" => "https://www.tiktok.com/@scout2015/video/6718335390845095173" }
        end
        .returns(oembed_payload)

      result =
        described_class.fetch(
          "https://m.tiktok.com/@scout2015/video/6718335390845095173?is_from_webapp=1",
        )

      expect(result).to eq(
        provider: "tiktok",
        external_id: "6718335390845095173",
        canonical_url: "https://www.tiktok.com/@scout2015/video/6718335390845095173",
        kind: "shorts",
        title: "Example TikTok video",
        description: nil,
        thumbnail_url: nil,
        duration_seconds: nil,
        author_name: "Scout",
      )
      expect(result).to be_frozen
    end

    it "sanitizes bounded text and ignores provider-supplied embed HTML and thumbnail URLs" do
      payload =
        oembed_payload.merge(
          "title" => "<b>Video</b> &amp; demo\n\t",
          "author_name" => "<i>Creator</i>\u0000 Name",
          "thumbnail_url" => "https://evil.test/tracker.jpg",
          "html" => '<blockquote><script src="https://evil.test/embed.js"></script></blockquote>',
        )
      VideoHub::ProviderJsonFetcher.expects(:fetch).returns(payload)

      result = described_class.fetch("https://www.tiktok.com/@scout2015/video/6718335390845095173")

      expect(result[:title]).to eq("Video & demo")
      expect(result[:author_name]).to eq("Creator Name")
      expect(result[:thumbnail_url]).to be_nil
      expect(result).not_to have_key(:html)
      expect(result).not_to have_key(:provider_thumbnail_url)
    end

    it "bounds title and author lengths after sanitization" do
      payload =
        oembed_payload.merge(
          "title" => "T" * (described_class::TITLE_MAX_LENGTH + 20),
          "author_name" => "A" * (described_class::AUTHOR_MAX_LENGTH + 20),
        )
      VideoHub::ProviderJsonFetcher.expects(:fetch).returns(payload)

      result = described_class.fetch("https://www.tiktok.com/@scout2015/video/6718335390845095173")

      expect(result[:title].length).to eq(described_class::TITLE_MAX_LENGTH)
      expect(result[:author_name].length).to eq(described_class::AUTHOR_MAX_LENGTH)
    end

    it "allows missing or empty optional title and author fields" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).returns(
        oembed_payload.merge("title" => "  \n\t", "author_name" => nil),
      )

      result = described_class.fetch("https://www.tiktok.com/@scout2015/video/6718335390845095173")

      expect(result[:title]).to be_nil
      expect(result[:author_name]).to be_nil
    end

    it "accepts the rich oEmbed type for video URLs while still discarding render HTML" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).returns(oembed_payload.merge("type" => "rich"))

      result = described_class.fetch("https://www.tiktok.com/@scout2015/video/6718335390845095173")

      expect(result[:external_id]).to eq("6718335390845095173")
      expect(result).not_to have_key(:html)
    end

    it "rejects non-TikTok sources before metadata network access" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).never

      expect_metadata_error("https://www.youtube.com/watch?v=dQw4w9WgXcQ", :unsupported_source)
    end

    it "rejects unsafe or malformed TikTok URLs before metadata network access" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).never

      expect_metadata_error(
        "http://www.tiktok.com/@scout2015/video/6718335390845095173",
        :unsupported_source,
      )
    end

    it "rejects unexpected provider identity from oEmbed" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).returns(
        oembed_payload.merge("provider_name" => "Not TikTok"),
      )

      expect_metadata_error(
        "https://www.tiktok.com/@scout2015/video/6718335390845095173",
        :invalid_metadata,
      )
    end

    it "rejects unexpected oEmbed types" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).returns(oembed_payload.merge("type" => "photo"))

      expect_metadata_error(
        "https://www.tiktok.com/@scout2015/video/6718335390845095173",
        :invalid_metadata,
      )
    end

    it "rejects malformed optional text fields" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).returns(
        oembed_payload.merge("author_name" => { "x" => 1 }),
      )

      expect_metadata_error(
        "https://www.tiktok.com/@scout2015/video/6718335390845095173",
        :invalid_metadata,
      )
    end

    it "maps bounded fetcher failures without leaking provider response details" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).raises(
        VideoHub::ProviderJsonFetcher::FetchError.new(:network_error),
      )

      expect_metadata_error(
        "https://www.tiktok.com/@scout2015/video/6718335390845095173",
        :network_error,
      )
    end
  end

  def oembed_payload
    {
      "provider_name" => "TikTok",
      "provider_url" => "https://www.tiktok.com",
      "type" => "video",
      "version" => "1.0",
      "title" => "Example TikTok video",
      "author_name" => "Scout",
      "author_url" => "https://www.tiktok.com/@scout2015",
      "thumbnail_url" => "https://p16-sign.tiktokcdn-us.com/example.jpeg",
      "html" => '<blockquote class="tiktok-embed"></blockquote>',
    }
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
