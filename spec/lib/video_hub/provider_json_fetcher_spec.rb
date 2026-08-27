# frozen_string_literal: true

describe VideoHub::ProviderJsonFetcher do
  let(:allowed_hosts) { %w[api.example.com metadata.example.com] }

  describe ".fetch" do
    it "returns a top-level JSON object from an allowlisted HTTPS endpoint" do
      fetcher =
        described_class.new("https://api.example.com/video/123", allowed_hosts: allowed_hosts)
      fetcher
        .expects(:request_once)
        .once
        .returns(
          response(
            200,
            content_type: "application/json; charset=utf-8",
            body: '{"title":"Example"}',
          ),
        )

      expect(fetcher.fetch).to eq("title" => "Example")
    end

    it "accepts structured JSON media types" do
      fetcher =
        described_class.new("https://api.example.com/video/123", allowed_hosts: allowed_hosts)
      fetcher
        .expects(:request_once)
        .once
        .returns(response(200, content_type: "application/problem+json", body: '{"ok":true}'))

      expect(fetcher.fetch).to eq("ok" => true)
    end

    it "rejects host-confusion URLs without network access" do
      FinalDestination::HTTP.expects(:start).never

      expect_fetch_error(
        described_class.new(
          "https://api.example.com.evil.test/video/123",
          allowed_hosts: allowed_hosts,
        ),
        :unsupported_host,
      )
    end

    it "rejects non-HTTPS URLs without network access" do
      FinalDestination::HTTP.expects(:start).never

      expect_fetch_error(
        described_class.new("http://api.example.com/video/123", allowed_hosts: allowed_hosts),
        :unsupported_scheme,
      )
    end

    it "rejects credentials without network access" do
      FinalDestination::HTTP.expects(:start).never

      expect_fetch_error(
        described_class.new(
          "https://internal.example@api.example.com/video/123",
          allowed_hosts: allowed_hosts,
        ),
        :credentials_not_allowed,
      )
    end

    it "rejects non-default HTTPS ports without network access" do
      FinalDestination::HTTP.expects(:start).never

      expect_fetch_error(
        described_class.new("https://api.example.com:8443/video/123", allowed_hosts: allowed_hosts),
        :unsupported_port,
      )
    end

    it "follows relative redirects only while every hop stays allowlisted" do
      fetcher = described_class.new("https://api.example.com/start", allowed_hosts: allowed_hosts)
      requested = []
      fetcher
        .stubs(:request_once)
        .with { |uri| requested << uri.to_s }
        .returns(
          response(302, location: "/v1/video/123"),
          response(302, location: "https://metadata.example.com/video/123"),
          response(200, content_type: "application/json", body: '{"id":"123"}'),
        )

      expect(fetcher.fetch).to eq("id" => "123")
      expect(requested).to eq(
        %w[
          https://api.example.com/start
          https://api.example.com/v1/video/123
          https://metadata.example.com/video/123
        ],
      )
    end

    it "rejects redirects to hosts outside the exact allowlist before requesting them" do
      fetcher = described_class.new("https://api.example.com/start", allowed_hosts: allowed_hosts)
      fetcher
        .expects(:request_once)
        .once
        .returns(response(302, location: "https://evil.test/video/123"))

      expect_fetch_error(fetcher, :redirect_host_not_allowed)
    end

    it "rejects insecure redirect destinations" do
      fetcher = described_class.new("https://api.example.com/start", allowed_hosts: allowed_hosts)
      fetcher
        .expects(:request_once)
        .once
        .returns(response(302, location: "http://api.example.com/video/123"))

      expect_fetch_error(fetcher, :invalid_redirect)
    end

    it "bounds redirect chains" do
      fetcher = described_class.new("https://api.example.com/start", allowed_hosts: allowed_hosts)
      fetcher
        .expects(:request_once)
        .times(described_class::MAX_REDIRECTS + 1)
        .returns(response(302, location: "https://api.example.com/next"))

      expect_fetch_error(fetcher, :too_many_redirects)
    end

    it "rejects redirects without a location" do
      fetcher = described_class.new("https://api.example.com/start", allowed_hosts: allowed_hosts)
      fetcher.expects(:request_once).once.returns(response(302))

      expect_fetch_error(fetcher, :missing_redirect)
    end

    it "rejects non-success provider responses with a stable error" do
      fetcher =
        described_class.new("https://api.example.com/video/123", allowed_hosts: allowed_hosts)
      fetcher.expects(:request_once).once.returns(response(503))

      expect_fetch_error(fetcher, :provider_response_error)
    end

    it "rejects non-JSON MIME types" do
      fetcher =
        described_class.new("https://api.example.com/video/123", allowed_hosts: allowed_hosts)
      fetcher
        .expects(:request_once)
        .once
        .returns(response(200, content_type: "text/html", body: '{"id":"123"}'))

      expect_fetch_error(fetcher, :invalid_content_type)
    end

    it "rejects malformed JSON" do
      fetcher =
        described_class.new("https://api.example.com/video/123", allowed_hosts: allowed_hosts)
      fetcher
        .expects(:request_once)
        .once
        .returns(response(200, content_type: "application/json", body: "{not-json"))

      expect_fetch_error(fetcher, :invalid_json)
    end

    it "rejects JSON deeper than the configured nesting bound" do
      nested =
        '{"root":' + ("[" * (described_class::MAX_JSON_DEPTH + 1)) + "0" +
          ("]" * (described_class::MAX_JSON_DEPTH + 1)) + "}"
      fetcher =
        described_class.new("https://api.example.com/video/123", allowed_hosts: allowed_hosts)
      fetcher
        .expects(:request_once)
        .once
        .returns(response(200, content_type: "application/json", body: nested))

      expect_fetch_error(fetcher, :json_too_deep)
    end

    it "requires a top-level JSON object" do
      fetcher =
        described_class.new("https://api.example.com/video/123", allowed_hosts: allowed_hosts)
      fetcher
        .expects(:request_once)
        .once
        .returns(response(200, content_type: "application/json", body: '[{"id":"123"}]'))

      expect_fetch_error(fetcher, :invalid_payload)
    end

    it "rejects oversized Content-Length before reading the body" do
      raw_response = mock
      raw_response.stubs(:code).returns("200")
      raw_response
        .stubs(:[])
        .with("content-length")
        .returns((described_class::MAX_RESPONSE_BYTES + 1).to_s)
      raw_response.stubs(:[]).with("location").returns(nil)
      raw_response.stubs(:[]).with("content-type").returns("application/json")
      raw_response.expects(:read_body).never

      expect_http_request(raw_response)

      expect_fetch_error(
        described_class.new("https://api.example.com/video/123", allowed_hosts: allowed_hosts),
        :response_too_large,
      )
    end

    it "enforces the byte limit while streaming when Content-Length is absent" do
      raw_response = mock
      raw_response.stubs(:code).returns("200")
      raw_response.stubs(:[]).with("content-length").returns(nil)
      raw_response.stubs(:[]).with("location").returns(nil)
      raw_response.stubs(:[]).with("content-type").returns("application/json")
      raw_response.expects(:read_body).yields("x" * (described_class::MAX_RESPONSE_BYTES + 1))

      expect_http_request(raw_response)

      expect_fetch_error(
        described_class.new("https://api.example.com/video/123", allowed_hosts: allowed_hosts),
        :response_too_large,
      )
    end

    it "uses Discourse SSRF-safe HTTP and sends no auth or cookie headers" do
      raw_response = mock
      raw_response.stubs(:code).returns("200")
      raw_response.stubs(:[]).with("content-length").returns(nil)
      raw_response.stubs(:[]).with("location").returns(nil)
      raw_response.stubs(:[]).with("content-type").returns("application/json")
      raw_response.expects(:read_body).yields('{"ok":true}')

      http = mock
      http
        .expects(:request)
        .with do |request|
          request.method == "GET" && request["Authorization"].nil? && request["Cookie"].nil? &&
            request["Accept"] == "application/json" && request["Accept-Encoding"] == "identity"
        end
        .yields(raw_response)

      FinalDestination::HTTP
        .expects(:start)
        .with(
          "api.example.com",
          443,
          use_ssl: true,
          open_timeout: described_class::TIMEOUT_SECONDS,
          read_timeout: described_class::TIMEOUT_SECONDS,
        )
        .yields(http)

      result =
        described_class.fetch("https://api.example.com/video/123", allowed_hosts: allowed_hosts)

      expect(result).to eq("ok" => true)
    end

    it "maps Discourse SSRF rejections to a stable safe error" do
      FinalDestination::HTTP.expects(:start).raises(
        FinalDestination::SSRFDetector::DisallowedIpError,
      )

      expect_fetch_error(
        described_class.new("https://api.example.com/video/123", allowed_hosts: allowed_hosts),
        :unsafe_network_target,
      )
    end

    it "maps network timeouts to a stable safe error" do
      FinalDestination::HTTP.expects(:start).raises(Timeout::Error)

      expect_fetch_error(
        described_class.new("https://api.example.com/video/123", allowed_hosts: allowed_hosts),
        :network_error,
      )
    end
  end

  def response(status, location: nil, content_type: nil, body: "")
    described_class::Response.new(
      status: status,
      location: location,
      content_type: content_type,
      body: body,
    )
  end

  def expect_http_request(raw_response)
    http = mock
    http.expects(:request).yields(raw_response)

    FinalDestination::HTTP
      .expects(:start)
      .with(
        "api.example.com",
        443,
        use_ssl: true,
        open_timeout: described_class::TIMEOUT_SECONDS,
        read_timeout: described_class::TIMEOUT_SECONDS,
      )
      .yields(http)
  end

  def expect_fetch_error(fetcher, code)
    expect { fetcher.fetch }.to raise_error(described_class::FetchError) do |error|
      expect(error.code).to eq(code)
      expect(error.message).to eq(code.to_s)
    end
  end
end
