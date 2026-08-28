# frozen_string_literal: true

module VideoHub
  class ProfileQuery
    PROVIDER_SETTINGS = {
      "youtube" => :video_hub_youtube_enabled,
      "tiktok" => :video_hub_tiktok_enabled,
      "instagram" => :video_hub_instagram_enabled,
    }.freeze

    ItemResult = Struct.new(:profile_item, :video, keyword_init: true)
    SectionResult = Struct.new(:profile_section, :items, keyword_init: true)
    Result = Struct.new(:profile_user, :sections, keyword_init: true)

    def self.fetch(user:, username:)
      new(user:, username:).fetch
    end

    def initialize(user:, username:)
      @guardian = Guardian.new(user)
      @username = username
    end

    def fetch
      profile_user = User.find_by_username(username)
      raise Discourse::NotFound unless profile_user && guardian.can_see_profile?(profile_user)

      sections =
        VideoHub::ProfileSection
          .where(user_id: profile_user.id, visible: true)
          .order(position: :asc, id: :asc)
          .map do |profile_section|
            SectionResult.new(
              profile_section: profile_section,
              items: visible_items(profile_section).freeze,
            ).freeze
          end

      Result.new(profile_user: profile_user, sections: sections.freeze).freeze
    end

    private

    attr_reader :guardian, :username

    def visible_items(profile_section)
      candidate_items(profile_section).filter_map do |profile_item|
        video = profile_item.video
        next unless guardian.can_see?(video.topic) && guardian.can_see?(video.post)

        ItemResult.new(profile_item: profile_item, video: video).freeze
      end
    end

    def candidate_items(profile_section)
      VideoHub::ProfileItem
        .joins(video: %i[topic post])
        .includes(video: %i[topic post])
        .where(profile_section_id: profile_section.id, visible: true)
        .where(
          video_hub_videos: {
            status: "published",
            provider: enabled_providers,
          },
          topics: {
            category_id: guardian.allowed_category_ids,
            deleted_at: nil,
            visible: true,
          },
          posts: {
            deleted_at: nil,
            hidden: false,
          },
        )
        .where.not(video_hub_videos: { published_at: nil })
        .order(position: :asc, id: :asc)
        .to_a
    end

    def enabled_providers
      PROVIDER_SETTINGS.filter_map do |provider, setting|
        provider if SiteSetting.public_send(setting)
      end
    end
  end
end
