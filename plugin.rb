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
  WATCH_PATH_PATTERN = %r{\A/videos/\d+/[^/.]+/?\z}
  PROFILE_PATH_PATTERN = %r{\A/u/[^/]+/videos(?:/|\z)}
end

require_relative "lib/video_hub/engine"

register_html_builder("server:before-head-close") do |controller|
  next unless SiteSetting.video_hub_enabled

  path = controller.request.path
  base_path = Discourse.base_path
  path = path.delete_prefix(base_path) if base_path.present?

  video_hub_path =
    path == "/videos" || path.start_with?("/videos/") ||
      path.match?(VideoHub::PROFILE_PATH_PATTERN)
  next unless video_hub_path
  next if path.match?(VideoHub::WATCH_PATH_PATTERN)

  '<meta name="robots" content="noindex,follow">'
end

after_initialize do
  require_relative "lib/video_hub/sitemap_controller_extension"
  require_relative "lib/video_hub/topic_view_canonical_extension"

  reloadable_patch do
    SitemapController.prepend(VideoHub::SitemapControllerExtension)
    TopicView.prepend(VideoHub::TopicViewCanonicalExtension)
  end

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
