# frozen_string_literal: true

module VideoHub
  class VideosController < ::ApplicationController
    requires_plugin VideoHub::PLUGIN_NAME

    AUTHORIZATION_ERROR_CODES = %i[
      login_required
      insufficient_trust
      not_allowed
      provider_disabled
    ].freeze

    before_action :ensure_video_hub_enabled
    before_action :ensure_logged_in, only: :create
    skip_before_action :check_xhr, only: :watch

    def index
      result =
        VideoHub::FeedQuery.fetch(
          user: current_user,
          cursor: params[:cursor],
          limit: params[:limit].presence || VideoHub::FeedQuery::DEFAULT_LIMIT,
        )

      render_json_dump(
        videos: result.videos.map { |video| video_payload(video) },
        providers: enabled_providers,
        pagination: {
          has_more: result.has_more,
          next_cursor: result.next_cursor,
        },
      )
    rescue VideoHub::FeedQuery::FeedError => error
      render json: { error: { code: error.code.to_s } }, status: :bad_request
    end

    def show
      result = VideoHub::WatchQuery.fetch(user: current_user, id: params[:id])

      render json: { video: video_payload(result.video, slug: result.slug) }
    end

    def watch
      result = VideoHub::WatchQuery.fetch(user: current_user, id: params[:id])
      seo = VideoHub::WatchSeo.build(video: result.video, slug: result.slug)

      if params[:slug] != result.slug
        return redirect_to(seo.canonical_url, status: :moved_permanently)
      end

      @video_hub_watch_seo = seo
      @description_meta = seo.description
      canonical_url(seo.canonical_url)

      render :watch
    rescue Discourse::NotFound
      raise unless VideoHub::WatchQuery.gone?(user: current_user, id: params[:id])

      response.headers["X-Robots-Tag"] = "noindex"
      raise Discourse::NotFound.new(nil, status: 410)
    end

    def create
      params.require(:url)

      video =
        VideoHub::PublishVideo.publish(
          user: current_user,
          url: params[:url],
          caption: params[:caption],
        )

      render json: { video: video_payload(video) }, status: :created
    rescue VideoHub::PublishVideo::PublishError => error
      render json: { error: { code: error.code.to_s } }, status: publish_error_status(error.code)
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

    def video_payload(video, slug: video.topic.slug)
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
        watch_path: "/videos/#{video.id}/#{slug}",
      }
    end

    def publish_error_status(code)
      return :not_found if code == :video_hub_disabled
      return :forbidden if AUTHORIZATION_ERROR_CODES.include?(code)
      return :service_unavailable if code == :category_not_configured
      return :internal_server_error if code == :publish_failed

      :unprocessable_entity
    end
  end
end
