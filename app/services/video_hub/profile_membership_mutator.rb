# frozen_string_literal: true

module VideoHub
  class ProfileMembershipMutator
    class MembershipError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    AddResult = Struct.new(
      :profile_user,
      :profile_section,
      :profile_item,
      :created,
      keyword_init: true,
    )

    def self.add(user:, username:, video_id:)
      new(user: user, username: username).add(video_id: video_id)
    end

    def self.remove(user:, username:, video_id:)
      new(user: user, username: username).remove(video_id: video_id)
    end

    def initialize(user:, username:)
      @guardian = Guardian.new(user)
      @username = username
    end

    def add(video_id:)
      profile_user = authorized_profile_user!
      normalized_video_id = normalize_positive_integer(video_id)

      profile_user.with_lock do
        video = eligible_video!(normalized_video_id)
        profile_sections = locked_sections(profile_user)
        profile_section =
          profile_sections.find { |section| section.section_type == video.kind } ||
            create_section!(profile_user, profile_sections, video.kind)

        profile_items = locked_items(profile_section)
        existing_item = profile_items.find { |item| item.video_id == video.id }

        if existing_item
          AddResult.new(
            profile_user: profile_user,
            profile_section: profile_section,
            profile_item: existing_item,
            created: false,
          ).freeze
        else
          profile_item =
            VideoHub::ProfileItem.create!(
              profile_section: profile_section,
              video: video,
              position: next_position(profile_items),
              pinned: false,
              visible: true,
            )

          AddResult.new(
            profile_user: profile_user,
            profile_section: profile_section,
            profile_item: profile_item,
            created: true,
          ).freeze
        end
      end
    rescue ActiveRecord::RecordInvalid,
           ActiveRecord::RecordNotSaved,
           ActiveRecord::RecordNotUnique
      raise MembershipError.new(:invalid_membership)
    end

    def remove(video_id:)
      profile_user = authorized_profile_user!
      normalized_video_id = normalize_positive_integer(video_id)

      profile_user.with_lock do
        profile_sections = locked_sections(profile_user)
        profile_items = locked_profile_items(profile_sections)
        profile_item = profile_items.find { |item| item.video_id == normalized_video_id }

        if profile_item
          section_items =
            profile_items
              .select { |item| item.profile_section_id == profile_item.profile_section_id }
              .sort_by { |item| [item.position, item.id] }

          profile_item.destroy!
          compact_positions!(section_items.reject { |item| item.id == profile_item.id })
          true
        else
          false
        end
      end
    rescue ActiveRecord::RecordInvalid,
           ActiveRecord::RecordNotSaved,
           ActiveRecord::RecordNotDestroyed,
           ActiveRecord::RecordNotUnique
      raise MembershipError.new(:invalid_membership)
    end

    private

    attr_reader :guardian, :username

    def authorized_profile_user!
      profile_user = User.find_by_username(username)
      raise Discourse::NotFound unless profile_user && guardian.can_edit_user?(profile_user)

      profile_user
    end

    def eligible_video!(video_id)
      video = VideoHub::Video.includes(:topic, :post).find_by(id: video_id)
      topic = video&.topic
      post = video&.post
      provider_setting = video && VideoHub::ProfileQuery::PROVIDER_SETTINGS[video.provider]

      raise Discourse::NotFound unless video && topic && post && provider_setting
      raise Discourse::NotFound unless video.status == "published" && video.published_at.present?
      raise Discourse::NotFound unless SiteSetting.public_send(provider_setting)
      raise Discourse::NotFound unless topic.deleted_at.nil? && topic.visible
      raise Discourse::NotFound unless post.deleted_at.nil? && !post.hidden
      raise Discourse::NotFound unless guardian.can_see?(topic) && guardian.can_see?(post)

      video
    end

    def locked_sections(profile_user)
      VideoHub::ProfileSection.where(user_id: profile_user.id).lock.order(:position, :id).to_a
    end

    def locked_items(profile_section)
      VideoHub::ProfileItem
        .where(profile_section_id: profile_section.id)
        .lock
        .order(:position, :id)
        .to_a
    end

    def locked_profile_items(profile_sections)
      return [] if profile_sections.empty?

      VideoHub::ProfileItem
        .where(profile_section_id: profile_sections.map(&:id))
        .lock
        .order(:profile_section_id, :position, :id)
        .to_a
    end

    def create_section!(profile_user, profile_sections, section_type)
      VideoHub::ProfileSection.create!(
        user: profile_user,
        section_type: section_type,
        title: nil,
        position: next_position(profile_sections),
        visible: true,
      )
    end

    def next_position(records)
      records.empty? ? 0 : records.map(&:position).max + 1
    end

    def compact_positions!(records)
      records.each_with_index do |record, position|
        record.update!(position: position) unless record.position == position
      end
    end

    def normalize_positive_integer(value)
      return value if value.is_a?(Integer) && value.positive?
      return value.to_i if value.is_a?(String) && value.match?(/\A[1-9]\d*\z/)

      raise MembershipError.new(:invalid_membership)
    end
  end
end
