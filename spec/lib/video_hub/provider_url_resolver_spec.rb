# frozen_string_literal: true

describe VideoHub::ProviderUrlResolver do
  describe ".resolve" do
    it "returns locally parsed provider URLs without network access" do
      FinalDestination::HTTP.expects(:start).never

      result = described_class.resolve("https://youtu.be/dQw4w9WgXcQ?t=42")

      expect(result).to have_attributes(
        provider: "youtube",
        external_id: "dQw4w9WgXcQ",
        canonical_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      )
    end

    it "resolves a TikTok short host through allowlisted redirects" do
      resolver = described_class.new("https://vm.tiktok.com/ZMabc123/")
      requested = []
      resolver
        .stubs(:request_once)
        .with { |uri| requested << uri.to_s }
        .returns(
          response(302, "https://www.tiktok.com/t/ZMabc123/"),
          response(
            302,
            "https://www.tiktok.com/@creator/video/7481234567890123456?is_from_webapp=1",
          ),
          response(200),
        )

      result = resolver.resolve

      expect(requested).to eq(
        %w[
          https://vm.tiktok.com/ZMabc123/
          https://www.tiktok.com/t/ZMabc123/
          https://www.tiktok.com/@creator/video/7481234567890123456?is_from_webapp=1
        ],
      )
      expect(result).to have_attributes(
        provider: "tiktok",
        external_id: "7481234567890123456",
        canonical_url: "https://www.tiktok.com/@creator/video/7481234567890123456",
      )
    end

    it "accepts direct www.tiktok.com short share URLs" do
      resolver = described_class.new("https://www.tiktok.com/t/ZMabc123/?_t=tracking")
      resolver.stubs(:request_once).returns(
        response(302, "https://www.tiktok.com/@creator/video/7481234567890123456"),
        response(200),
      )

      result = resolver.resolve

      expect(result.external_id).to eq("7481234567890123456")
    end

    it "supports relative redirects while keeping the host policy" do
      resolver = described_class.new("https://vt.tiktok.com/ZMabc123/")
      requested = []
      resolver
        .stubs(:request_once)
        .with { |uri| requested << uri.to_s }
        .returns(
          response(302, "/t/ZMabc123/"),
          response(302, "https://www.tiktok.com/@creator/video/7481234567890123456"),
          response(200),
        )

      resolver.resolve

      expect(requested[1]).to eq("https://vt.tiktok.com/t/ZMabc123/")
    end

    it "rejects a redirect to a non-TikTok public host before requesting it" do
      resolver = described_class.new("https://vm.tiktok.com/ZMabc123/")
      resolver.expects(:request_once).once.returns(response(302, "https://example.com/video"))

      expect_resolve_error(resolver, :redirect_host_not_allowed)
    end

    it "rejects non-HTTPS short URLs without network access" do
      FinalDestination::HTTP.expects(:start).never

      expect_resolve_error(
        described_class.new("http://vm.tiktok.com/ZMabc123/"),
        :unsupported_scheme,
      )
    end

    it "rejects credentials in short URLs without network access" do
      FinalDestination::HTTP.expects(:start).never

      expect_resolve_error(
        described_class.new("https://evil.example@vm.tiktok.com/ZMabc123/"),
        :credentials_not_allowed,
      )
    end

    it "rejects malformed TikTok short paths without network access" do
      FinalDestination::HTTP.expects(:start).never

      expect_resolve_error(
        described_class.new("https://vm.tiktok.com/not/a/share/path"),
        :unsupported_path,
      )
    end

    it "bounds redirect chains" do
      resolver = described_class.new("https://vm.tiktok.com/ZMabc123/")
      resolver
        .expects(:request_once)
        .times(5)
        .returns(response(302, "https://www.tiktok.com/t/ZMabc123/"))

      expect_resolve_error(resolver, :too_many_redirects)
    end

    it "rejects redirects without a location" do
      resolver = described_class.new("https://vm.tiktok.com/ZMabc123/")
      resolver.expects(:request_once).once.returns(response(302))

      expect_resolve_error(resolver, :missing_redirect)
    end

    it "requires the final destination to be a canonical TikTok video URL" do
      resolver = described_class.new("https://vm.tiktok.com/ZMabc123/")
      resolver.expects(:request_once).once.returns(response(200))

      expect_resolve_error(resolver, :invalid_destination)
    end

    it "maps non-success provider responses to a stable error" do
      resolver = described_class.new("https://vm.tiktok.com/ZMabc123/")
      resolver.expects(:request_once).once.returns(response(503))

      expect_resolve_error(resolver, :provider_response_error)
    end

    it "uses Discourse SSRF-safe HTTP without sending auth or cookie headers" do
      raw_response = mock
      raw_response.stubs(:code).returns("302")
      raw_response.stubs(:[]).with("location").returns("https://example.com/video")

      http = mock
      http.expects(:read_timeout=).with(described_class::TIMEOUT_SECONDS)
      http
        .expects(:request)
        .with do |request|
          request.method == "GET" && request["Authorization"].nil? && request["Cookie"].nil?
        end
        .yields(raw_response)

      FinalDestination::HTTP
        .expects(:start)
        .with("vm.tiktok.com", 443, use_ssl: true, open_timeout: described_class::TIMEOUT_SECONDS)
        .yields(http)

      expect_resolve_error(
        described_class.new("https://vm.tiktok.com/ZMabc123/"),
        :redirect_host_not_allowed,
      )
    end

    it "maps Discourse SSRF rejections without leaking target details" do
      FinalDestination::HTTP.expects(:start).raises(
        FinalDestination::SSRFDetector::DisallowedIpError,
      )

      expect_resolve_error(
        described_class.new("https://vm.tiktok.com/ZMabc123/"),
        :unsafe_network_target,
      )
    end

    it "maps network failures to a stable safe error" do
      FinalDestination::HTTP.expects(:start).raises(Timeout::Error)

      expect_resolve_error(described_class.new("https://vm.tiktok.com/ZMabc123/"), :network_error)
    end
  end

  def response(status, location = nil)
    described_class::Response.new(status: status, location: location)
  end

  def expect_resolve_error(resolver, code)
    expect { resolver.resolve }.to raise_error(described_class::ResolveError) do |error|
      expect(error.code).to eq(code)
      expect(error.message).to eq(code.to_s)
    end
  end
end
