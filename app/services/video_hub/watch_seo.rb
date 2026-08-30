# frozen_string_literal: true

module VideoHub
  class WatchSeo
    Result =
      Struct.new(
        :title,
        :document_title,
        :description,
        :canonical_path,
        :canonical_url,
        :image_url,
        :published_at,
        :source_url,
        :json_ld,
        keyword_init: true,
      )

    def self.build(video:, slug:)
      new(video:, slug:).build
    end

    def initialize(video:, slug:)
      @video = video
      @slug = slug
    end

    def build
      title = @video.title.presence || @video.topic.title
      description = @video.description.presence || title
      canonical_path = "/videos/#{@video.id}/#{@slug}"
      canonical_url = "#{Discourse.base_url}#{canonical_path}"
      image_url = safe_http_url(@video.thumbnail_url)
      source_url = safe_http_url(@video.canonical_url)
      published_at = @video.published_at

      Result.new(
        title: title,
        document_title: document_title(title),
        description: description,
        canonical_path: canonical_path,
        canonical_url: canonical_url,
        image_url: image_url,
        published_at: published_at,
        source_url: source_url,
        json_ld:
          build_json_ld(
            title: title,
            description: description,
            canonical_url: canonical_url,
            image_url: image_url,
            published_at: published_at,
            source_url: source_url,
          ),
      ).freeze
    end

    private

    def document_title(title)
      return title if SiteSetting.title.blank? || title == SiteSetting.title

      "#{title} - #{SiteSetting.title}"
    end

    def build_json_ld(title:, description:, canonical_url:, image_url:, published_at:, source_url:)
      return if image_url.blank? || published_at.blank?

      data = {
        "@context" => "https://schema.org",
        "@type" => "VideoObject",
        "name" => title,
        "description" => description,
        "thumbnailUrl" => [image_url],
        "uploadDate" => published_at.iso8601,
        "url" => canonical_url,
      }
      data["contentUrl"] = source_url if source_url.present?
      data["duration"] = "PT#{@video.duration_seconds}S" if @video.duration_seconds.to_i.positive?
      if @video.author_name.present?
        data["author"] = { "@type" => "Person", "name" => @video.author_name }
      end

      data.freeze
    end

    def safe_http_url(value)
      return if value.blank?

      uri = Addressable::URI.parse(value)
      return if %w[http https].exclude?(uri.scheme&.downcase)
      return if uri.host.blank?

      value
    rescue Addressable::URI::InvalidURIError
      nil
    end
  end
end
