# frozen_string_literal: true

require "cgi"
require "uri"

module VideoHub
  module Providers
    class Instagram
      OEMBED_HOST = "graph.facebook.com"
      OEMBED_PATH = "/v25.0/instagram_oembed"
      REEL_PREFIX = "https://www.instagram.com/reel/"
      TITLE_MAX_LENGTH = 300
      AUTHOR_MAX_LENGTH = 200

      class MetadataError < StandardError
        attr_reader :code

        def initialize(code)
          @code = code
          super(code.to_s)
        end
      end

      def self.fetch(input)
        new(input).fetch
      end

      def initialize(input)
        @input = input
      end

      def fetch
        parsed = parse_source
        payload =
          VideoHub::ProviderJsonFetcher.fetch(oembed_url(parsed), allowed_hosts: [OEMBED_HOST])

        validate_payload!(payload)

        {
          provider: "instagram",
          external_id: parsed.external_id,
          canonical_url: parsed.canonical_url,
          kind: "shorts",
          title: sanitize_text(payload["title"], max_length: TITLE_MAX_LENGTH),
          description: nil,
          thumbnail_url: nil,
          duration_seconds: nil,
          author_name: sanitize_text(payload["author_name"], max_length: AUTHOR_MAX_LENGTH),
        }.freeze
      rescue VideoHub::ProviderJsonFetcher::FetchError => error
        raise MetadataError.new(error.code)
      end

      private

      attr_reader :input

      def parse_source
        parsed = VideoHub::ProviderUrlParser.parse(input)
        unless parsed.provider == "instagram" && parsed.canonical_url.start_with?(REEL_PREFIX)
          raise MetadataError.new(:unsupported_source)
        end

        parsed
      rescue VideoHub::ProviderUrlParser::ParseError
        raise MetadataError.new(:unsupported_source)
      end

      def oembed_url(parsed)
        URI::HTTPS.build(
          host: OEMBED_HOST,
          path: OEMBED_PATH,
          query: URI.encode_www_form(url: parsed.canonical_url),
        ).to_s
      end

      def validate_payload!(payload)
        unless payload["provider_name"] == "Instagram" && payload["type"] == "rich"
          raise MetadataError.new(:invalid_metadata)
        end
      end

      def sanitize_text(value, max_length:)
        return if value.nil?
        raise MetadataError.new(:invalid_metadata) unless value.is_a?(String)

        text = CGI.unescapeHTML(Sanitize.fragment(value))
        text = text.gsub(/[[:cntrl:]]+/, " ").gsub(/\s+/, " ").strip
        return if text.empty?

        text[0, max_length]
      end
    end
  end
end
