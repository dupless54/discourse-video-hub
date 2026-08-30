# frozen_string_literal: true

require "digest"

module VideoHub
  class ProviderMetadataFetcher
    CACHE_VERSION = 1
    SUCCESS_CACHE_TTL = 30.minutes
    FAILURE_CACHE_TTL = 1.minute
    CACHE_KEY_PREFIX = "video_hub:provider_metadata"
    CACHEABLE_METADATA_KEYS = %i[
      provider
      external_id
      canonical_url
      kind
      title
      description
      thumbnail_url
      duration_seconds
      author_name
    ].freeze
    SAFE_ERROR_CODE = /\A[a-z0-9_]{1,64}\z/

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

      if (metadata = read_success_cache(resolved))
        return metadata
      end

      if (error_code = read_failure_cache(resolved))
        raise MetadataError.new(error_code)
      end

      metadata = adapter_for(resolved.provider).fetch(resolved.canonical_url)
      write_success_cache(resolved, metadata)
      Discourse.cache.delete(cache_key(resolved, "failure"))
      metadata
    rescue VideoHub::ProviderUrlResolver::ResolveError => error
      raise MetadataError.new(error.code)
    rescue VideoHub::Providers::Youtube::MetadataError,
           VideoHub::Providers::Tiktok::MetadataError,
           VideoHub::Providers::Instagram::MetadataError => error
      write_failure_cache(resolved, error.code) if resolved
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

    def read_success_cache(resolved)
      key = cache_key(resolved, "success")
      cached = Discourse.cache.read(key)
      return unless cached

      metadata = deserialize_metadata(cached, resolved)
      return metadata.freeze if metadata

      Discourse.cache.delete(key)
      nil
    end

    def write_success_cache(resolved, metadata)
      cached = serialize_metadata(metadata, resolved)
      return unless cached

      Discourse.cache.write(
        cache_key(resolved, "success"),
        cached,
        expires_in: SUCCESS_CACHE_TTL,
      )
    end

    def read_failure_cache(resolved)
      key = cache_key(resolved, "failure")
      cached = Discourse.cache.read(key)
      return cached.to_sym if cached.is_a?(String) && cached.match?(SAFE_ERROR_CODE)

      Discourse.cache.delete(key) if cached
      nil
    end

    def write_failure_cache(resolved, code)
      cached = code.to_s
      return unless cached.match?(SAFE_ERROR_CODE)

      Discourse.cache.write(
        cache_key(resolved, "failure"),
        cached,
        expires_in: FAILURE_CACHE_TTL,
      )
    end

    def serialize_metadata(metadata, resolved)
      return unless metadata.is_a?(Hash)
      return unless metadata[:provider] == resolved.provider
      return unless metadata[:external_id] == resolved.external_id
      return unless metadata[:canonical_url] == resolved.canonical_url

      CACHEABLE_METADATA_KEYS.each_with_object({}) do |key, result|
        result[key.to_s] = metadata[key] if metadata.key?(key)
      end
    end

    def deserialize_metadata(cached, resolved)
      return unless cached.is_a?(Hash)

      metadata =
        CACHEABLE_METADATA_KEYS.each_with_object({}) do |key, result|
          string_key = key.to_s
          result[key] = cached[string_key] if cached.key?(string_key)
        end

      return unless metadata[:provider] == resolved.provider
      return unless metadata[:external_id] == resolved.external_id
      return unless metadata[:canonical_url] == resolved.canonical_url

      metadata
    end

    def cache_key(resolved, kind)
      identity = [resolved.provider, resolved.external_id, resolved.canonical_url].join("\0")
      digest = Digest::SHA256.hexdigest(identity)
      "#{CACHE_KEY_PREFIX}:v#{CACHE_VERSION}:#{kind}:#{digest}"
    end
  end
end
