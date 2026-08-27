# frozen_string_literal: true

describe VideoHub::Providers::Youtube do
  describe ".fetch" do
    it "fetches normalized metadata through the fixed YouTube oEmbed endpoint" do
      ProviderJsonFetcher
        .expects(:fetch)
        .with do |url, allowed_hosts:|
          uri = URI.parse(url)
          query = URI.decode_www_form(uri.query).to_h

          uri.scheme == "https" && uri.host == "www.youtube.com" && uri.port == 443 &&
            uri.path == "/oembed" && allowed_hosts == ["www.youtube.com"] &&
            query ==
              {
                "url" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                "format" => "json",
              }
        end
        .returns(oembed_payload)

      result = described_class.fetch("https://youtu.be/dQw4w9WgXcQ?t=42")

      expect(result).to eq(
        provider: "youtube",
        external_id: "dQw4w9WgXcQ",
        canonical_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        kind: "landscape",
        title: "Example video",
        description: nil,
        thumbnail_url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        duration_seconds: nil,
        author_name: "Example creator",
      )
      expect(result).to be_frozen
    end

    it "preserves Shorts identity and marks the normalized kind as shorts" do
      ProviderJsonFetcher.expects(:fetch).returns(oembed_payload)

      result = described_class.fetch("https://www.youtube.com/shorts/dQw4w9WgXcQ?feature=share")

      expect(result).to include(
        external_id: "dQw4w9WgXcQ",
        canonical_url: "https://www.youtube.com/shorts/dQw4w9WgXcQ",
        kind: "shorts",
      )
    end

    it "sanitizes bounded text and ignores provider-supplied embed HTML and thumbnail URLs" do
      payload =
        oembed_payload.merge(
          "title" => "<b>Video</b> &amp; demo\n\t",
          "author_name" => "<i>Creator</i>\u0000 Name",
          "thumbnail_url" => "https://evil.test/tracker.jpg",
          "html" => '<iframe src="https://evil.test/embed"></iframe>',
        )
      ProviderJsonFetcher.expects(:fetch).returns(payload)

      result = described_class.fetch("https://www.youtube.com/watch?v=dQw4w9WgXcQ")

      expect(result[:title]).to eq("Video & demo")
      expect(result[:author_name]).to eq("Creator Name")
      expect(result[:thumbnail_url]).to eq("https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
      expect(result).not_to have_key(:html)
      expect(result).not_to have_key(:provider_thumbnail_url)
    end

    it "bounds title and author lengths after sanitization" do
      payload =
        oembed_payload.merge(
          "title" => "T" * (described_class::TITLE_MAX_LENGTH + 20),
          "author_name" => "A" * (described_class::AUTHOR_MAX_LENGTH + 20),
        )
      ProviderJsonFetcher.expects(:fetch).returns(payload)

      result = described_class.fetch("https://www.youtube.com/watch?v=dQw4w9WgXcQ")

      expect(result[:title].length).to eq(described_class::TITLE_MAX_LENGTH)
      expect(result[:author_name].length).to eq(described_class::AUTHOR_MAX_LENGTH)
    end

    it "allows a missing optional author name" do
      ProviderJsonFetcher.expects(:fetch).returns(oembed_payload.merge("author_name" => nil))

      result = described_class.fetch("https://www.youtube.com/watch?v=dQw4w9WgXcQ")

      expect(result[:author_name]).to be_nil
    end

    it "rejects non-YouTube sources before metadata network access" do
      ProviderJsonFetcher.expects(:fetch).never

      expect_metadata_error(
        "https://www.instagram.com/reel/AbCdEf123/",
        :unsupported_source,
      )
    end

    it "rejects unsafe or malformed YouTube URLs before metadata network access" do
      ProviderJsonFetcher.expects(:fetch).never

      expect_metadata_error("http://www.youtube.com/watch?v=dQw4w9WgXcQ", :unsupported_source)
    end

    it "rejects unexpected provider identity from oEmbed" do
      ProviderJsonFetcher
        .expects(:fetch)
        .returns(oembed_payload.merge("provider_name" => "Not YouTube"))

      expect_metadata_error(
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        :invalid_metadata,
      )
    end

    it "rejects unexpected oEmbed types" do
      ProviderJsonFetcher.expects(:fetch).returns(oembed_payload.merge("type" => "rich"))

      expect_metadata_error(
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        :invalid_metadata,
      )
    end

    it "requires a non-empty sanitized title" do
      ProviderJsonFetcher.expects(:fetch).returns(oembed_payload.merge("title" => "   \n\t"))

      expect_metadata_error(
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        :invalid_metadata,
      )
    end

    it "rejects malformed optional text fields" do
      ProviderJsonFetcher.expects(:fetch).returns(oembed_payload.merge("author_name" => { "x" => 1 }))

      expect_metadata_error(
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        :invalid_metadata,
      )
    end

    it "maps bounded fetcher failures without leaking provider response details" do
      ProviderJsonFetcher
        .expects(:fetch)
        .raises(ProviderJsonFetcher::FetchError.new(:network_error))

      expect_metadata_error(
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        :network_error,
      )
    end
  end

  def oembed_payload
    {
      "provider_name" => "YouTube",
      "provider_url" => "https://www.youtube.com/",
      "type" => "video",
      "version" => "1.0",
      "title" => "Example video",
      "author_name" => "Example creator",
      "author_url" => "https://www.youtube.com/@example",
      "thumbnail_url" => "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
      "thumbnail_width" => 480,
      "thumbnail_height" => 360,
      "html" => '<iframe src="https://www.youtube.com/embed/dQw4w9WgXcQ"></iframe>',
    }
  end

  def expect_metadata_error(input, code)
    expect { described_class.fetch(input) }.to raise_error(described_class::MetadataError) do |error|
      expect(error.code).to eq(code)
      expect(error.message).to eq(code.to_s)
    end
  end
end
