# frozen_string_literal: true

module VideoHub
  class VideosController < ::ApplicationController
    requires_plugin VideoHub::PLUGIN_NAME

    before_action :ensure_video_hub_enabled

    def index
      render_json_dump(
        videos: [],
        providers: enabled_providers,
        pagination: {
          has_more: false,
          next_cursor: nil,
        },
      )
    end

    private

    def ensure_video_hub_enabled
      raise Discourse::NotFound unless SiteSetting.video_hub_enabled
    end

    def enabled_providers
      providers = []
      providers << "youtube" if SiteSetting.video_hub_youtube_enabled
      providers << "tiktok" if SiteSetting.video_hub_tiktok_enabled
      providers << "instagram" if SiteSetting.video_hub_instagram_enabled
      providers
    end
  end
end
