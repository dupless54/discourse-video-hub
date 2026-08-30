# frozen_string_literal: true

describe VideoHub::Providers::Instagram do
  describe ".fetch" do
    it "fetches normalized Reel metadata through the fixed Meta oEmbed endpoint" do
      VideoHub::ProviderJsonFetcher
        .expects(:fetch)
        .with do |url, allowed_hosts:|
          uri = URI.parse(url)
          query = URI.decode_www_form(uri.query).to_h

          uri.scheme == "https" && uri.host == "graph.facebook.com" && uri.port == 443 &&
            uri.path == "/v25.0/instagram_oembed" && allowed_hosts == ["graph.facebook.com"] &&
            query == { "url" => "https://www.instagram.com/reel/AbCdEf123/" }
        end
        .returns(oembed_payload)

      result = described_class.fetch("https://instagram.com/reel/AbCdEf123/?utm_source=share")

      expect(result).to eq(
        provider: "instagram",
        external_id: "AbCdEf123",
        canonical_url: "https://www.instagram.com/reel/AbCdEf123/",
        kind: "shorts",
        title: "Example Instagram Reel",
        description: nil,
        thumbnail_url: nil,
        duration_seconds: nil,
        author_name: "Example creator",
      )
      expect(result).to be_frozen
    end

    it "sanitizes bounded text and ignores provider-supplied embed HTML and thumbnail URLs" do
      payload =
        oembed_payload.merge(
          "title" => "<b>Reel</b> &amp; demo\n\t",
          "author_name" => "<i>Creator</i>\u0000 Name",
          "thumbnail_url" => "https://evil.test/tracker.jpg",
          "html" => '<blockquote><script src="https://evil.test/embed.js"></script></blockquote>',
        )
      VideoHub::ProviderJsonFetcher.expects(:fetch).returns(payload)

      result = described_class.fetch("https://www.instagram.com/reel/AbCdEf123/")

      expect(result[:title]).to eq("Reel & demo")
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

      result = described_class.fetch("https://www.instagram.com/reel/AbCdEf123/")

      expect(result[:title].length).to eq(described_class::TITLE_MAX_LENGTH)
      expect(result[:author_name].length).to eq(described_class::AUTHOR_MAX_LENGTH)
    end

    it "allows missing or empty optional title and author fields" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).returns(
        oembed_payload.merge("title" => "  \n\t", "author_name" => nil),
      )

      result = described_class.fetch("https://www.instagram.com/reel/AbCdEf123/")

      expect(result[:title]).to be_nil
      expect(result[:author_name]).to be_nil
    end

    it "rejects Instagram post URLs because oEmbed does not prove that /p/ media is video" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).never

      expect_metadata_error("https://www.instagram.com/p/AbCdEf123/", :unsupported_source)
    end

    it "rejects legacy Instagram TV URLs not covered by Meta's current provider contract" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).never

      expect_metadata_error("https://www.instagram.com/tv/AbCdEf123/", :unsupported_source)
    end

    it "rejects non-Instagram sources before metadata network access" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).never

      expect_metadata_error("https://www.youtube.com/watch?v=dQw4w9WgXcQ", :unsupported_source)
    end

    it "rejects unsafe or malformed Instagram URLs before metadata network access" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).never

      expect_metadata_error("http://www.instagram.com/reel/AbCdEf123/", :unsupported_source)
    end

    it "rejects unexpected provider identity from oEmbed" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).returns(
        oembed_payload.merge("provider_name" => "Not Instagram"),
      )

      expect_metadata_error("https://www.instagram.com/reel/AbCdEf123/", :invalid_metadata)
    end

    it "rejects unexpected oEmbed types" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).returns(oembed_payload.merge("type" => "video"))

      expect_metadata_error("https://www.instagram.com/reel/AbCdEf123/", :invalid_metadata)
    end

    it "rejects malformed optional text fields" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).returns(
        oembed_payload.merge("author_name" => { "x" => 1 }),
      )

      expect_metadata_error("https://www.instagram.com/reel/AbCdEf123/", :invalid_metadata)
    end

    it "maps bounded fetcher failures without leaking provider response details" do
      VideoHub::ProviderJsonFetcher.expects(:fetch).raises(
        VideoHub::ProviderJsonFetcher::FetchError.new(:network_error),
      )

      expect_metadata_error("https://www.instagram.com/reel/AbCdEf123/", :network_error)
    end
  end

  def oembed_payload
    {
      "provider_name" => "Instagram",
      "provider_url" => "https://www.instagram.com/",
      "type" => "rich",
      "version" => "1.0",
      "title" => "Example Instagram Reel",
      "author_name" => "Example creator",
      "author_url" => "https://www.instagram.com/example/",
      "thumbnail_url" => "https://scontent.example.test/reel.jpg",
      "html" => '<blockquote class="instagram-media"></blockquote>',
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
