# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module VideoHub
  class ProviderJsonFetcher
    REDIRECT_STATUSES = [301, 302, 303, 307, 308].freeze
    MAX_REDIRECTS = 3
    MAX_RESPONSE_BYTES = 256 * 1024
    MAX_JSON_DEPTH = 16
    TIMEOUT_SECONDS = 3
    JSON_MEDIA_TYPE = %r{\Aapplication/(?:json|[a-z0-9._+-]+\+json)\z}
    REQUEST_HEADERS = {
      "Accept" => "application/json",
      "Accept-Encoding" => "identity",
      "User-Agent" => FinalDestination::DEFAULT_USER_AGENT,
    }.freeze

    Response = Struct.new(:status, :location, :content_type, :body, keyword_init: true)

    class FetchError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    def self.fetch(url, allowed_hosts:)
      new(url, allowed_hosts: allowed_hosts).fetch
    end

    def initialize(url, allowed_hosts:)
      @url = url
      @allowed_hosts = Array(allowed_hosts).map { |host| host.to_s.downcase }.uniq.freeze
    end

    def fetch
      uri = parse_initial_uri
      redirect_count = 0

      loop do
        response = request_once(uri)

        if REDIRECT_STATUSES.include?(response.status)
          if response.location.nil? || response.location.empty?
            raise FetchError.new(:missing_redirect)
          end
          raise FetchError.new(:too_many_redirects) if redirect_count >= MAX_REDIRECTS

          uri = redirect_uri(uri, response.location)
          validate_redirect_uri!(uri)
          redirect_count += 1
          next
        end

        raise FetchError.new(:provider_response_error) unless (200..299).cover?(response.status)

        validate_content_type!(response.content_type)
        payload = parse_json(response.body)
        raise FetchError.new(:invalid_payload) unless payload.is_a?(Hash)

        return payload
      end
    end

    private

    attr_reader :allowed_hosts, :url

    def parse_initial_uri
      validate_input!
      uri = URI.parse(url)
      validate_initial_uri!(uri)
      uri.fragment = nil
      uri
    rescue URI::InvalidURIError
      raise FetchError.new(:invalid_url)
    end

    def validate_input!
      unless url.is_a?(String) && url == url.strip && !url.empty? && !url.match?(/[[:cntrl:]]/)
        raise FetchError.new(:invalid_url)
      end
    end

    def validate_initial_uri!(uri)
      raise FetchError.new(:unsupported_scheme) unless uri.is_a?(URI::HTTPS)
      raise FetchError.new(:credentials_not_allowed) if uri.userinfo
      raise FetchError.new(:unsupported_port) unless uri.port == 443

      host = uri.host&.downcase
      raise FetchError.new(:unsupported_host) if host.nil? || allowed_hosts.exclude?(host)
    end

    def redirect_uri(current_uri, location)
      uri = URI.join(current_uri.to_s, location)
      uri.fragment = nil
      uri
    rescue URI::Error
      raise FetchError.new(:invalid_redirect)
    end

    def validate_redirect_uri!(uri)
      raise FetchError.new(:invalid_redirect) unless uri.is_a?(URI::HTTPS)
      raise FetchError.new(:invalid_redirect) if uri.userinfo
      raise FetchError.new(:invalid_redirect) unless uri.port == 443

      host = uri.host&.downcase
      raise FetchError.new(:redirect_host_not_allowed) if host.nil? || allowed_hosts.exclude?(host)
    end

    def validate_content_type!(content_type)
      media_type = content_type.to_s.split(";", 2).first.to_s.strip.downcase
      raise FetchError.new(:invalid_content_type) unless media_type.match?(JSON_MEDIA_TYPE)
    end

    def parse_json(body)
      JSON.parse(body, max_nesting: MAX_JSON_DEPTH)
    rescue JSON::NestingError
      raise FetchError.new(:json_too_deep)
    rescue JSON::ParserError
      raise FetchError.new(:invalid_json)
    end

    def request_once(uri)
      response_data = nil

      FinalDestination::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: TIMEOUT_SECONDS,
        read_timeout: TIMEOUT_SECONDS,
      ) do |http|
        request = Net::HTTP::Get.new(uri.request_uri, REQUEST_HEADERS)

        http.request(request) do |response|
          status = response.code.to_i
          body = +""

          if REDIRECT_STATUSES.exclude?(status)
            ensure_content_length!(response["content-length"])

            response.read_body do |chunk|
              body << chunk
              raise FetchError.new(:response_too_large) if body.bytesize > MAX_RESPONSE_BYTES
            end
          end

          response_data =
            Response.new(
              status: status,
              location: response["location"],
              content_type: response["content-type"],
              body: body,
            )
        end
      end

      response_data
    rescue FinalDestination::SSRFDetector::DisallowedIpError
      raise FetchError.new(:unsafe_network_target)
    rescue FinalDestination::SSRFDetector::LookupFailedError,
           SocketError,
           Timeout::Error,
           SystemCallError,
           EOFError,
           IOError,
           OpenSSL::SSL::SSLError
      raise FetchError.new(:network_error)
    end

    def ensure_content_length!(value)
      content_length = Integer(value, exception: false)
      return if content_length.nil? || content_length <= MAX_RESPONSE_BYTES

      raise FetchError.new(:response_too_large)
    end
  end
end
