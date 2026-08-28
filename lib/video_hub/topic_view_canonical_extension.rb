# frozen_string_literal: true

module VideoHub
  module TopicViewCanonicalExtension
    def canonical_path
      core_path = super
      return core_path unless SiteSetting.video_hub_enabled
      return core_path if SiteSetting.embed_set_canonical_url && topic.topic_embed

      video_id = VideoHub::Video.where(topic_id: topic.id, status: "published").pick(:id)
      return core_path unless video_id

      result = VideoHub::WatchQuery.fetch(user: guardian.user, id: video_id)
      "/videos/#{result.video.id}/#{result.slug}"
    rescue Discourse::NotFound
      core_path
    end
  end
end
