# frozen_string_literal: true

require "uri"

module VideoHub
  class ProviderUrlParser
    YOUTUBE_HOSTS = %w[youtube.com www.youtube.com m.youtube.com].freeze
    YOUTUBE_SHORT_HOST = "youtu.be"
    TIKTOK_HOSTS = %w[tiktok.com www.tiktok.com m.tiktok.com].freeze
    INSTAGRAM_HOSTS = %w[instagram.com www.instagram.com].freeze
    YOUTUBE_ID = /\A[A-Za-z0-9_-]{11}\z/
    TIKTOK_VIDEO_PATH = %r{\A/@([A-Za-z0-9._]+)/video/([0-9]{6,30})/?\z}
    INSTAGRAM_MEDIA_PATH = %r{\A/(reel|p|tv)/([A-Za-z0-9_-]{5,64})/?\z}

    Result = Struct.new(:provider, :external_id, :canonical_url, keyword_init: true)

    class ParseError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    def self.parse(input)
      new(input).parse
    end

    def initialize(input)
      @input = input
    end

    def parse
      uri = parse_uri
      validate_common_uri!(uri)

      host = uri.host.downcase

      if YOUTUBE_HOSTS.include?(host)
        parse_youtube(uri)
      elsif host == YOUTUBE_SHORT_HOST
        parse_youtube_short_url(uri)
      elsif TIKTOK_HOSTS.include?(host)
        parse_tiktok(uri)
      elsif INSTAGRAM_HOSTS.include?(host)
        parse_instagram(uri)
      else
        raise ParseError.new(:unsupported_host)
      end
    end

    private

    attr_reader :input

    def parse_uri
      unless input.is_a?(String) && input == input.strip && !input.empty? && !input.match?(/[[:cntrl:]]/)
        raise ParseError.new(:invalid_url)
      end

      URI.parse(input)
    rescue URI::InvalidURIError
      raise ParseError.new(:invalid_url)
    end

    def validate_common_uri!(uri)
      raise ParseError.new(:unsupported_scheme) unless uri.is_a?(URI::HTTPS)
      raise ParseError.new(:credentials_not_allowed) if uri.userinfo
      raise ParseError.new(:unsupported_host) if uri.host.nil? || uri.host.empty?
      raise ParseError.new(:unsupported_port) unless uri.port == 443
    end

    def parse_youtube(uri)
      if (match = uri.path.match(%r{\A/shorts/([A-Za-z0-9_-]{11})/?\z}))
        external_id = match[1]
        return result("youtube", external_id, "https://www.youtube.com/shorts/#{external_id}")
      end

      raise ParseError.new(:unsupported_path) unless uri.path == "/watch"

      video_ids = query_values(uri, "v")
      raise ParseError.new(:invalid_external_id) unless video_ids.length == 1 && video_ids.first.match?(YOUTUBE_ID)

      external_id = video_ids.first
      result("youtube", external_id, "https://www.youtube.com/watch?v=#{external_id}")
    end

    def parse_youtube_short_url(uri)
      match = uri.path.match(%r{\A/([A-Za-z0-9_-]{11})/?\z})
      raise ParseError.new(:invalid_external_id) unless match

      external_id = match[1]
      result("youtube", external_id, "https://www.youtube.com/watch?v=#{external_id}")
    end

    def parse_tiktok(uri)
      match = uri.path.match(TIKTOK_VIDEO_PATH)
      raise ParseError.new(:unsupported_path) unless match

      username = match[1]
      external_id = match[2]
      result("tiktok", external_id, "https://www.tiktok.com/@#{username}/video/#{external_id}")
    end

    def parse_instagram(uri)
      match = uri.path.match(INSTAGRAM_MEDIA_PATH)
      raise ParseError.new(:unsupported_path) unless match

      media_type = match[1]
      external_id = match[2]
      result("instagram", external_id, "https://www.instagram.com/#{media_type}/#{external_id}/")
    end

    def query_values(uri, key)
      return [] if uri.query.nil?

      URI.decode_www_form(uri.query).filter_map { |name, value| value if name == key }
    rescue ArgumentError
      raise ParseError.new(:invalid_url)
    end

    def result(provider, external_id, canonical_url)
      Result.new(provider: provider, external_id: external_id, canonical_url: canonical_url).freeze
    end
  end
end
