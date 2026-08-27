# frozen_string_literal: true

require "net/http"
require "uri"

module VideoHub
  class ProviderUrlResolver
    SHORT_TIKTOK_HOSTS = %w[vm.tiktok.com vt.tiktok.com].freeze
    TIKTOK_RESOLUTION_HOSTS =
      (ProviderUrlParser::TIKTOK_HOSTS + SHORT_TIKTOK_HOSTS).uniq.freeze
    SHORT_HOST_PATH = %r{\A/[A-Za-z0-9_-]{4,128}/?\z}
    WEB_SHARE_PATH = %r{\A/t/[A-Za-z0-9_-]{4,128}/?\z}
    REDIRECT_STATUSES = [301, 302, 303, 307, 308].freeze
    MAX_REDIRECTS = 4
    TIMEOUT_SECONDS = 3
    REQUEST_HEADERS = {
      "Accept" => "text/html,application/xhtml+xml;q=0.9,*/*;q=0.1",
      "User-Agent" => FinalDestination::DEFAULT_USER_AGENT,
    }.freeze

    Response = Struct.new(:status, :location, keyword_init: true)

    class ResolveError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    def self.resolve(input)
      new(input).resolve
    end

    def initialize(input)
      @input = input
    end

    def resolve
      parser_error = nil

      begin
        return ProviderUrlParser.parse(input)
      rescue ProviderUrlParser::ParseError => error
        parser_error = error
      end

      share_uri = parse_share_uri
      raise ResolveError.new(parser_error.code) unless share_uri

      final_uri = follow_redirects(share_uri)
      parse_final_uri(final_uri)
    end

    private

    attr_reader :input

    def parse_share_uri
      validate_input!
      uri = URI.parse(input)
      validate_common_uri!(uri)

      host = uri.host.downcase

      if SHORT_TIKTOK_HOSTS.include?(host)
        raise ResolveError.new(:unsupported_path) unless uri.path.match?(SHORT_HOST_PATH)
      elsif ProviderUrlParser::TIKTOK_HOSTS.include?(host)
        return unless uri.path.match?(WEB_SHARE_PATH)
      else
        return
      end

      uri.fragment = nil
      uri
    rescue URI::InvalidURIError
      raise ResolveError.new(:invalid_url)
    end

    def validate_input!
      unless input.is_a?(String) && input == input.strip && !input.empty? &&
               !input.match?(/[[:cntrl:]]/)
        raise ResolveError.new(:invalid_url)
      end
    end

    def validate_common_uri!(uri)
      raise ResolveError.new(:unsupported_scheme) unless uri.is_a?(URI::HTTPS)
      raise ResolveError.new(:credentials_not_allowed) if uri.userinfo
      raise ResolveError.new(:unsupported_host) if uri.host.nil? || uri.host.empty?
      raise ResolveError.new(:unsupported_port) unless uri.port == 443
    end

    def follow_redirects(start_uri)
      uri = start_uri
      redirect_count = 0

      loop do
        response = request_once(uri)

        if REDIRECT_STATUSES.include?(response.status)
          raise ResolveError.new(:missing_redirect) if response.location.nil? || response.location.empty?
          raise ResolveError.new(:too_many_redirects) if redirect_count >= MAX_REDIRECTS

          uri = redirect_uri(uri, response.location)
          validate_redirect_uri!(uri)
          redirect_count += 1
          next
        end

        return uri if (200..299).cover?(response.status)

        raise ResolveError.new(:provider_response_error)
      end
    end

    def redirect_uri(current_uri, location)
      uri = URI.join(current_uri.to_s, location)
      uri.fragment = nil
      uri
    rescue URI::Error
      raise ResolveError.new(:invalid_redirect)
    end

    def validate_redirect_uri!(uri)
      raise ResolveError.new(:invalid_redirect) unless uri.is_a?(URI::HTTPS)
      raise ResolveError.new(:invalid_redirect) if uri.userinfo
      raise ResolveError.new(:invalid_redirect) unless uri.port == 443

      host = uri.host&.downcase
      raise ResolveError.new(:redirect_host_not_allowed) unless TIKTOK_RESOLUTION_HOSTS.include?(host)
    end

    def parse_final_uri(uri)
      result = ProviderUrlParser.parse(uri.to_s)
      raise ResolveError.new(:invalid_destination) unless result.provider == "tiktok"

      result
    rescue ProviderUrlParser::ParseError
      raise ResolveError.new(:invalid_destination)
    end

    def request_once(uri)
      catch(:video_hub_response) do
        FinalDestination::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: true,
          open_timeout: TIMEOUT_SECONDS,
        ) do |http|
          http.read_timeout = TIMEOUT_SECONDS
          request = Net::HTTP::Get.new(uri.request_uri, REQUEST_HEADERS)

          http.request(request) do |response|
            throw :video_hub_response,
                  Response.new(status: response.code.to_i, location: response["location"])
          end
        end
      end
    rescue FinalDestination::SSRFDetector::DisallowedIpError
      raise ResolveError.new(:unsafe_network_target)
    rescue FinalDestination::SSRFDetector::LookupFailedError,
           SocketError,
           Timeout::Error,
           SystemCallError,
           EOFError,
           IOError,
           OpenSSL::SSL::SSLError
      raise ResolveError.new(:network_error)
    end
  end
end
