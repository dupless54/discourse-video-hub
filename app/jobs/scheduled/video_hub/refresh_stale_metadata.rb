# frozen_string_literal: true

module Jobs
  module VideoHub
    class RefreshStaleMetadata < ::Jobs::Scheduled
      BATCH_SIZE = 50

      every 1.hour

      def execute(args)
        return unless SiteSetting.video_hub_enabled

        candidate_ids.each do |video_id|
          ::Jobs.enqueue(::Jobs::VideoHub::RefreshVideoMetadata, video_id: video_id)
        end
      end

      def candidate_ids
        providers = enabled_providers
        return [] if providers.empty?

        cutoff = ::VideoHub::RefreshVideoMetadata::STALE_AFTER.ago
        ::VideoHub::Video
          .where(status: "published", provider: providers)
          .where("metadata_refreshed_at IS NULL OR metadata_refreshed_at < ?", cutoff)
          .order(Arel.sql("metadata_refreshed_at ASC NULLS FIRST, id ASC"))
          .limit(BATCH_SIZE)
          .pluck(:id)
      end

      private

      def enabled_providers
        ::VideoHub::PublishPolicy::PROVIDER_SETTINGS.filter_map do |provider, setting|
          provider if SiteSetting.public_send(setting)
        end
      end
    end
  end
end
