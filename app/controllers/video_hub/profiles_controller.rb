# frozen_string_literal: true

module VideoHub
  class ProfilesController < ::ApplicationController
    requires_plugin VideoHub::PLUGIN_NAME

    before_action :ensure_video_hub_enabled

    def show
      result = VideoHub::ProfileQuery.fetch(user: current_user, username: params[:username])

      render json: {
               profile: {
                 username: result.profile_user.username,
                 sections: result.sections.map { |section| section_payload(section) },
               },
             }
    end

    private

    def ensure_video_hub_enabled
      raise Discourse::NotFound unless SiteSetting.video_hub_enabled
    end

    def section_payload(result)
      section = result.profile_section

      {
        id: section.id,
        section_type: section.section_type,
        title: section.title,
        position: section.position,
        items: result.items.map { |item| item_payload(item) },
      }
    end

    def item_payload(result)
      item = result.profile_item

      {
        id: item.id,
        position: item.position,
        pinned: item.pinned,
        video: video_payload(result.video),
      }
    end

    def video_payload(video)
      {
        id: video.id,
        provider: video.provider,
        external_id: video.external_id,
        canonical_url: video.canonical_url,
        kind: video.kind,
        title: video.title,
        thumbnail_url: video.thumbnail_url,
        duration_seconds: video.duration_seconds,
        author_name: video.author_name,
        topic_id: video.topic_id,
        post_id: video.post_id,
        published_at: video.published_at&.iso8601,
        watch_path: "/videos/#{video.id}/#{video.topic.slug}",
      }
    end
  end
end
