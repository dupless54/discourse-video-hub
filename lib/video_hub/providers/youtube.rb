# frozen_string_literal: true

require "cgi"
require "uri"

module VideoHub
  module Providers
    class Youtube
      OEMBED_HOST = "www.youtube.com"
      OEMBED_PATH = "/oembed"
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
          ProviderJsonFetcher.fetch(oembed_url(parsed), allowed_hosts: [OEMBED_HOST])

        validate_payload!(payload)

        {
          provider: "youtube",
          external_id: parsed.external_id,
          canonical_url: parsed.canonical_url,
          kind: video_kind(parsed),
          title: sanitize_text(payload["title"], max_length: TITLE_MAX_LENGTH, required: true),
          description: nil,
          thumbnail_url: "https://i.ytimg.com/vi/#{parsed.external_id}/hqdefault.jpg",
          duration_seconds: nil,
          author_name: sanitize_text(payload["author_name"], max_length: AUTHOR_MAX_LENGTH),
        }.freeze
      rescue ProviderJsonFetcher::FetchError => error
        raise MetadataError.new(error.code)
      end

      private

      attr_reader :input

      def parse_source
        parsed = ProviderUrlParser.parse(input)
        raise MetadataError.new(:unsupported_source) unless parsed.provider == "youtube"

        parsed
      rescue ProviderUrlParser::ParseError
        raise MetadataError.new(:unsupported_source)
      end

      def oembed_url(parsed)
        URI::HTTPS.build(
          host: OEMBED_HOST,
          path: OEMBED_PATH,
          query: URI.encode_www_form(url: parsed.canonical_url, format: "json"),
        ).to_s
      end

      def validate_payload!(payload)
        unless payload["provider_name"] == "YouTube" && payload["type"] == "video"
          raise MetadataError.new(:invalid_metadata)
        end
      end

      def video_kind(parsed)
        parsed.canonical_url.start_with?("https://www.youtube.com/shorts/") ? "shorts" : "landscape"
      end

      def sanitize_text(value, max_length:, required: false)
        if value.nil?
          raise MetadataError.new(:invalid_metadata) if required
          return
        end
        raise MetadataError.new(:invalid_metadata) unless value.is_a?(String)

        text = CGI.unescapeHTML(Sanitize.fragment(value))
        text = text.gsub(/[[:cntrl:]]+/, " ").gsub(/\s+/, " ").strip
        raise MetadataError.new(:invalid_metadata) if required && text.empty?

        text[0, max_length]
      end
    end
  end
end
