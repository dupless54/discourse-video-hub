# frozen_string_literal: true

module VideoHub
  class ProfileLayoutQuery
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
      raise Discourse::NotFound unless profile_user && guardian.can_edit_user?(profile_user)

      sections =
        VideoHub::ProfileSection
          .where(user_id: profile_user.id)
          .includes(items: { video: %i[topic post] })
          .order(position: :asc, id: :asc)
          .map do |profile_section|
            SectionResult.new(
              profile_section: profile_section,
              items: section_items(profile_section).freeze,
            ).freeze
          end

      Result.new(profile_user: profile_user, sections: sections.freeze).freeze
    end

    private

    attr_reader :guardian, :username

    def section_items(profile_section)
      profile_section.items.sort_by { |item| [item.position, item.id] }.map do |profile_item|
        video = profile_item.video
        ensure_backing_content_visible!(video)

        ItemResult.new(profile_item: profile_item, video: video).freeze
      end
    end

    def ensure_backing_content_visible!(video)
      topic = video&.topic
      post = video&.post

      raise Discourse::NotFound unless topic && post
      raise Discourse::NotFound unless topic.deleted_at.nil? && topic.visible
      raise Discourse::NotFound unless post.deleted_at.nil? && !post.hidden
      raise Discourse::NotFound unless guardian.can_see?(topic) && guardian.can_see?(post)
    end
  end
end
