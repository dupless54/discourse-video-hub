# frozen_string_literal: true

module VideoHub
  class RefreshVideoMetadata
    STALE_AFTER = 24.hours
    LOCK_PREFIX = "video_hub_metadata_refresh"
    MUTABLE_METADATA_KEYS = %i[title description thumbnail_url duration_seconds author_name].freeze

    def self.refresh(video_id:)
      new(video_id:).refresh
    end

    def initialize(video_id:)
      @video_id = Integer(video_id, exception: false)
    end

    def refresh
      video = find_video
      return :missing unless video
      return :ineligible unless eligible?(video)
      return :fresh if fresh?(video)

      DistributedMutex.synchronize(lock_key(video.id), validity: 5.minutes) do
        video = find_video
        next :missing unless video
        next :ineligible unless eligible?(video)
        next :fresh if fresh?(video)

        refresh_locked(video)
      end
    end

    private

    attr_reader :video_id

    def find_video
      return unless video_id&.positive?

      VideoHub::Video.includes(:topic, :post).find_by(id: video_id)
    end

    def eligible?(video)
      return false unless SiteSetting.video_hub_enabled
      return false unless video.status == "published" && video.published_at
      return false unless video.topic && video.post
      return false if video.topic.deleted_at || video.post.deleted_at

      provider_setting = VideoHub::PublishPolicy::PROVIDER_SETTINGS[video.provider]
      provider_setting && SiteSetting.public_send(provider_setting)
    end

    def fresh?(video)
      video.metadata_refreshed_at && video.metadata_refreshed_at >= STALE_AFTER.ago
    end

    def refresh_locked(video)
      metadata = VideoHub::ProviderMetadataFetcher.refresh(video.canonical_url)

      unless matching_identity?(metadata, video)
        mark_attempt(video)
        Rails.logger.warn("[VideoHub] metadata refresh identity mismatch video_id=#{video.id}")
        return :identity_mismatch
      end

      attributes = metadata.slice(*MUTABLE_METADATA_KEYS)
      video.update!(attributes.merge(metadata_refreshed_at: Time.zone.now))
      :refreshed
    rescue VideoHub::ProviderMetadataFetcher::MetadataError => error
      mark_attempt(video)
      Rails.logger.warn(
        "[VideoHub] metadata refresh failed video_id=#{video.id} code=#{error.code}",
      )
      :failed
    end

    def matching_identity?(metadata, video)
      metadata.is_a?(Hash) && metadata[:provider] == video.provider &&
        metadata[:external_id] == video.external_id &&
        metadata[:canonical_url] == video.canonical_url && metadata[:kind] == video.kind
    end

    def mark_attempt(video)
      VideoHub::Video.where(id: video.id).update_all(metadata_refreshed_at: Time.zone.now)
    end

    def lock_key(id)
      "#{LOCK_PREFIX}:#{id}"
    end
  end
end
