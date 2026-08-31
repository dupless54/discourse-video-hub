# frozen_string_literal: true

# name: discourse-video-hub
# about: Native video discovery and profile showcases for public video links
# version: 1.0.0-rc.1
# authors: dupless54
# url: https://github.com/dupless54/discourse-video-hub

enabled_site_setting :video_hub_enabled

register_asset "stylesheets/common/video-hub.scss"
register_asset "stylesheets/common/video-hub-profile.scss"
register_asset "stylesheets/common/video-hub-mobile-feed.scss"
register_asset "stylesheets/common/video-hub-saved.scss"
register_asset "stylesheets/common/video-hub-trending.scss"
register_asset "stylesheets/common/video-hub-following.scss"
register_asset "stylesheets/common/video-hub-collection.scss"
register_asset "stylesheets/common/video-hub-collections.scss"

module ::VideoHub
  PLUGIN_NAME = "discourse-video-hub"
end

require_relative "lib/video_hub/engine"

Discourse::Application.routes.append do
  get "/u/:username/videos" => "video_hub/videos#shell",
      :constraints => {
        username: RouteFormat.username,
        format: /html/,
      },
      :defaults => {
        format: :html,
      }
  get "/u/:username/videos/edit" => "video_hub/videos#shell",
      :constraints => {
        username: RouteFormat.username,
        format: /html/,
      },
      :defaults => {
        format: :html,
      }
end

after_initialize do
  require_relative "lib/video_hub/sitemap_controller_extension"
  require_relative "lib/video_hub/topic_view_canonical_extension"

  reloadable_patch do
    SitemapController.prepend(VideoHub::SitemapControllerExtension)
    TopicView.prepend(VideoHub::TopicViewCanonicalExtension)
  end

  Discourse::Application.routes.prepend do
    get "/videos.json" => "video_hub/videos#index", :defaults => { format: :json }
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
