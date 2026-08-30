# frozen_string_literal: true

module VideoHub
  module SitemapControllerExtension
    def build_sitemap_topic_url(slug, id, posts_count = nil)
      video = video_hub_sitemap_videos[id.to_i]
      return super(slug, id, posts_count) unless video

      "#{Discourse.base_url}/videos/#{video.id}/#{slug}"
    end

    private

    def video_hub_sitemap_videos
      return @video_hub_sitemap_videos if defined?(@video_hub_sitemap_videos)

      @video_hub_sitemap_videos = {}
      return @video_hub_sitemap_videos unless SiteSetting.video_hub_enabled

      topic_ids = Array(@topics).filter_map { |row| row[0] }.map(&:to_i)
      return @video_hub_sitemap_videos if topic_ids.empty?

      guardian = Guardian.new(nil)
      VideoHub::Video
        .includes(:topic, :post)
        .where(topic_id: topic_ids, status: "published")
        .each do |video|
          next unless VideoHub::WatchQuery.visible_video?(video, guardian:)

          @video_hub_sitemap_videos[video.topic_id] = video
        end

      @video_hub_sitemap_videos
    end
  end
end
