# frozen_string_literal: true

module VideoHub
  class ProviderMetadataFetcher
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
      resolved = VideoHub::ProviderUrlResolver.resolve(input)
      adapter_for(resolved.provider).fetch(resolved.canonical_url)
    rescue VideoHub::ProviderUrlResolver::ResolveError,
           VideoHub::Providers::Youtube::MetadataError,
           VideoHub::Providers::Tiktok::MetadataError,
           VideoHub::Providers::Instagram::MetadataError => error
      raise MetadataError.new(error.code)
    end

    private

    attr_reader :input

    def adapter_for(provider)
      case provider
      when "youtube"
        VideoHub::Providers::Youtube
      when "tiktok"
        VideoHub::Providers::Tiktok
      when "instagram"
        VideoHub::Providers::Instagram
      else
        raise MetadataError.new(:unsupported_provider)
      end
    end
  end
end
