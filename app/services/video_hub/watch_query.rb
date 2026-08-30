# frozen_string_literal: true

module VideoHub
  class WatchQuery
    MAX_RECORD_ID = 9_223_372_036_854_775_807

    PROVIDER_SETTINGS = {
      "youtube" => :video_hub_youtube_enabled,
      "tiktok" => :video_hub_tiktok_enabled,
      "instagram" => :video_hub_instagram_enabled,
    }.freeze

    Result = Struct.new(:video, :slug, keyword_init: true)

    def self.fetch(user:, id:)
      new(user:, id:).fetch
    end

    def self.visible_video?(video, guardian:)
      return false unless video

      provider_setting = PROVIDER_SETTINGS[video.provider]
      return false unless provider_setting && SiteSetting.public_send(provider_setting)
      return false unless video.published_at
      return false unless video.topic && video.post
      return false if video.topic.deleted_at || video.post.deleted_at

      guardian.can_see?(video.topic) && guardian.can_see?(video.post)
    end

    def initialize(user:, id:)
      @guardian = Guardian.new(user)
      @id = parse_id(id)
    end

    def fetch
      video = VideoHub::Video.includes(:topic, :post, :user).find_by(id: @id, status: "published")

      raise Discourse::NotFound unless visible_video?(video)

      Result.new(video:, slug: video.topic.slug).freeze
    end

    private

    def parse_id(value)
      raw_id = value.to_s
      raise Discourse::NotFound unless raw_id.match?(/\A[1-9][0-9]*\z/)

      id = raw_id.to_i
      raise Discourse::NotFound if id > MAX_RECORD_ID

      id
    end

    def visible_video?(video)
      self.class.visible_video?(video, guardian: @guardian)
    end
  end
end
