# frozen_string_literal: true

describe VideoHub::ProviderUrlParser do
  describe ".parse" do
    it "normalizes YouTube watch URLs and removes tracking parameters" do
      result = described_class.parse("https://m.youtube.com/watch?v=dQw4w9WgXcQ&utm_source=test")

      expect(result).to have_attributes(
        provider: "youtube",
        external_id: "dQw4w9WgXcQ",
        canonical_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      )
    end

    it "normalizes YouTube Shorts URLs" do
      result = described_class.parse("https://www.youtube.com/shorts/dQw4w9WgXcQ?feature=share")

      expect(result).to have_attributes(
        provider: "youtube",
        external_id: "dQw4w9WgXcQ",
        canonical_url: "https://www.youtube.com/shorts/dQw4w9WgXcQ",
      )
    end

    it "normalizes youtu.be share URLs" do
      result = described_class.parse("https://youtu.be/dQw4w9WgXcQ?t=42")

      expect(result).to have_attributes(
        provider: "youtube",
        external_id: "dQw4w9WgXcQ",
        canonical_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      )
    end

    it "normalizes canonical TikTok video URLs" do
      result =
        described_class.parse(
          "https://www.tiktok.com/@creator.name/video/7481234567890123456?is_from_webapp=1",
        )

      expect(result).to have_attributes(
        provider: "tiktok",
        external_id: "7481234567890123456",
        canonical_url: "https://www.tiktok.com/@creator.name/video/7481234567890123456",
      )
    end

    it "normalizes Instagram Reel URLs" do
      result = described_class.parse("https://www.instagram.com/reel/C9Ab_cdEF12/?igsh=example")

      expect(result).to have_attributes(
        provider: "instagram",
        external_id: "C9Ab_cdEF12",
        canonical_url: "https://www.instagram.com/reel/C9Ab_cdEF12/",
      )
    end

    it "accepts Instagram post URLs as media candidates for metadata verification" do
      result = described_class.parse("https://instagram.com/p/C9Ab_cdEF12/")

      expect(result).to have_attributes(
        provider: "instagram",
        external_id: "C9Ab_cdEF12",
        canonical_url: "https://www.instagram.com/p/C9Ab_cdEF12/",
      )
    end

    it "rejects non-HTTPS URLs before provider parsing" do
      expect_parse_error("http://www.youtube.com/watch?v=dQw4w9WgXcQ", :unsupported_scheme)
    end

    it "rejects credential components even when the final host is allowed" do
      expect_parse_error(
        "https://evil.example@www.youtube.com/watch?v=dQw4w9WgXcQ",
        :credentials_not_allowed,
      )
    end

    it "uses exact host matching instead of suffix matching" do
      expect_parse_error(
        "https://www.youtube.com.evil.example/watch?v=dQw4w9WgXcQ",
        :unsupported_host,
      )
    end

    it "rejects unexpected ports" do
      expect_parse_error("https://www.youtube.com:444/watch?v=dQw4w9WgXcQ", :unsupported_port)
    end

    it "rejects ambiguous YouTube video identifiers" do
      expect_parse_error(
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ&v=aaaaaaaaaaa",
        :invalid_external_id,
      )
    end

    it "rejects unsupported provider paths" do
      expect_parse_error("https://www.instagram.com/stories/example/123456789/", :unsupported_path)
    end

    it "does not resolve TikTok redirect hosts inside the local parser" do
      expect_parse_error("https://vm.tiktok.com/ZMexample/", :unsupported_host)
    end

    it "rejects surrounding whitespace and control characters" do
      expect_parse_error(" https://youtu.be/dQw4w9WgXcQ", :invalid_url)
      expect_parse_error("https://youtu.be/dQw4w9WgXcQ\n", :invalid_url)
    end
  end

  def expect_parse_error(url, code)
    expect { described_class.parse(url) }.to raise_error(described_class::ParseError) do |error|
      expect(error.code).to eq(code)
    end
  end
end
