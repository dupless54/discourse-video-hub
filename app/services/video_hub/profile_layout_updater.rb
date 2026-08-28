# frozen_string_literal: true

module VideoHub
  class ProfileLayoutUpdater
    class LayoutError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    SectionResult = Struct.new(:profile_section, :items, keyword_init: true)
    Result = Struct.new(:profile_user, :sections, keyword_init: true)

    def self.update(user:, username:, sections:)
      new(user: user, username: username, sections: sections).update
    end

    def initialize(user:, username:, sections:)
      @guardian = Guardian.new(user)
      @username = username
      @sections = sections
    end

    def update
      profile_user = User.find_by_username(username)
      raise Discourse::NotFound unless profile_user && guardian.can_edit_user?(profile_user)

      requested_sections = normalize_sections

      VideoHub::ProfileSection.transaction do
        profile_sections =
          VideoHub::ProfileSection.where(user_id: profile_user.id).lock.order(:id).to_a
        validate_section_layout!(profile_sections, requested_sections)

        profile_items =
          VideoHub::ProfileItem
            .where(profile_section_id: profile_sections.map(&:id))
            .lock
            .order(:id)
            .to_a

        validate_item_layout!(profile_sections, profile_items, requested_sections)
        ensure_backing_content_visible!(profile_items)

        apply_layout!(profile_sections, profile_items, requested_sections)
        build_result(profile_user, profile_sections, profile_items, requested_sections)
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique
      raise LayoutError.new(:invalid_layout)
    end

    private

    attr_reader :guardian, :username, :sections

    def normalize_sections
      raise_layout_error unless sections.is_a?(Array)

      sections.map do |section|
        attributes = normalize_hash(section)
        raise_layout_error unless section_shape_valid?(attributes)

        {
          id: attributes[:id],
          position: attributes[:position],
          title: attributes[:title],
          visible: attributes[:visible],
          items: normalize_items(attributes[:items]),
        }
      end
    end

    def normalize_items(items)
      raise_layout_error unless items.is_a?(Array)

      items.map do |item|
        attributes = normalize_hash(item)
        raise_layout_error unless item_shape_valid?(attributes)

        {
          id: attributes[:id],
          position: attributes[:position],
          pinned: attributes[:pinned],
          visible: attributes[:visible],
        }
      end
    end

    def normalize_hash(value)
      raise_layout_error unless value.respond_to?(:to_h)

      value.to_h.deep_symbolize_keys
    end

    def section_shape_valid?(attributes)
      required_keys = %i[id position title visible items]
      required_keys.all? { |key| attributes.key?(key) } &&
        valid_id?(attributes[:id]) &&
        valid_position?(attributes[:position]) &&
        valid_title?(attributes[:title]) &&
        boolean?(attributes[:visible])
    end

    def item_shape_valid?(attributes)
      required_keys = %i[id position pinned visible]
      required_keys.all? { |key| attributes.key?(key) } &&
        valid_id?(attributes[:id]) &&
        valid_position?(attributes[:position]) &&
        boolean?(attributes[:pinned]) &&
        boolean?(attributes[:visible])
    end

    def valid_id?(value)
      value.is_a?(Integer) && value.positive?
    end

    def valid_position?(value)
      value.is_a?(Integer) && value >= 0
    end

    def valid_title?(value)
      return true if value.nil?

      value.is_a?(String) &&
        !value.include?("\u0000") &&
        value.length <= VideoHub::ProfileSection::TITLE_MAX_LENGTH
    end

    def boolean?(value)
      value == true || value == false
    end

    def validate_section_layout!(profile_sections, requested_sections)
      validate_exact_ids!(profile_sections.map(&:id), requested_sections.map { |section| section[:id] })
      validate_contiguous_positions!(requested_sections)
    end

    def validate_item_layout!(profile_sections, profile_items, requested_sections)
      items_by_section = profile_items.group_by(&:profile_section_id)

      profile_sections.each do |profile_section|
        requested_section = requested_sections.find { |section| section[:id] == profile_section.id }
        requested_items = requested_section[:items]
        existing_items = items_by_section.fetch(profile_section.id, [])

        validate_exact_ids!(existing_items.map(&:id), requested_items.map { |item| item[:id] })
        validate_contiguous_positions!(requested_items)
      end
    end

    def validate_exact_ids!(existing_ids, requested_ids)
      raise_layout_error unless requested_ids.uniq.length == requested_ids.length
      raise_layout_error unless existing_ids.sort == requested_ids.sort
    end

    def validate_contiguous_positions!(records)
      positions = records.map { |record| record[:position] }
      raise_layout_error unless positions.sort == (0...records.length).to_a
    end

    def ensure_backing_content_visible!(profile_items)
      videos =
        VideoHub::Video
          .where(id: profile_items.map(&:video_id))
          .includes(:topic, :post)
          .index_by(&:id)

      profile_items.each do |profile_item|
        video = videos[profile_item.video_id]
        raise Discourse::NotFound unless video&.topic && video.post
        raise Discourse::NotFound unless guardian.can_see?(video.topic) && guardian.can_see?(video.post)
      end
    end

    def apply_layout!(profile_sections, profile_items, requested_sections)
      temporarily_move_positions!(profile_sections)
      profile_items.group_by(&:profile_section_id).each_value do |items|
        temporarily_move_positions!(items)
      end

      sections_by_id = profile_sections.index_by(&:id)
      items_by_id = profile_items.index_by(&:id)

      requested_sections.each do |requested_section|
        sections_by_id.fetch(requested_section[:id]).update!(
          title: requested_section[:title],
          position: requested_section[:position],
          visible: requested_section[:visible],
        )

        requested_section[:items].each do |requested_item|
          items_by_id.fetch(requested_item[:id]).update!(
            position: requested_item[:position],
            pinned: requested_item[:pinned],
            visible: requested_item[:visible],
          )
        end
      end
    end

    def temporarily_move_positions!(records)
      return if records.empty?

      base = records.map(&:position).max.to_i + records.length + 1
      records.each_with_index do |record, index|
        record.update_columns(position: base + index)
      end
    end

    def build_result(profile_user, profile_sections, profile_items, requested_sections)
      sections_by_id = profile_sections.index_by(&:id)
      items_by_id = profile_items.index_by(&:id)

      ordered_sections =
        requested_sections
          .sort_by { |section| section[:position] }
          .map do |requested_section|
            ordered_items =
              requested_section[:items]
                .sort_by { |item| item[:position] }
                .map { |item| items_by_id.fetch(item[:id]) }
                .freeze

            SectionResult.new(
              profile_section: sections_by_id.fetch(requested_section[:id]),
              items: ordered_items,
            ).freeze
          end
          .freeze

      Result.new(profile_user: profile_user, sections: ordered_sections).freeze
    end

    def raise_layout_error
      raise LayoutError.new(:invalid_layout)
    end
  end
end
