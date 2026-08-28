# frozen_string_literal: true

# name: discourse-video-hub
# about: Native video discovery and profile showcases for public video links
# version: 0.1.0
# authors: dupless54
# url: https://github.com/dupless54/discourse-video-hub

enabled_site_setting :video_hub_enabled

register_asset "stylesheets/common/video-hub.scss"
register_asset "stylesheets/common/video-hub-profile.scss"
register_asset "stylesheets/common/video-hub-mobile-feed.scss"

module ::VideoHub
  PLUGIN_NAME = "discourse-video-hub"
end

require_relative "lib/video_hub/engine"

after_initialize do
  Discourse::Application.routes.prepend do
    get "/videos/:id/:slug" => "video_hub/videos#watch",
        :constraints => {
          id: /\d+/,
          slug: %r{[^./]+},
          format: /html/,
        },
        :defaults => {
          format: :html,
        }
  end

  Discourse::Application.routes.append { mount ::VideoHub::Engine, at: "/videos" }
end
