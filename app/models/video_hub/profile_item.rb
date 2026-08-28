# frozen_string_literal: true

module VideoHub
  class ProfileItem < ActiveRecord::Base
    belongs_to :profile_section,
               class_name: "VideoHub::ProfileSection",
               inverse_of: :items
    belongs_to :video, class_name: "VideoHub::Video"

    validates :video_id,
              uniqueness: {
                scope: :profile_section_id,
              }
    validates :position,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
              },
              uniqueness: {
                scope: :profile_section_id,
              }
    validates :pinned, inclusion: { in: [true, false] }
    validates :visible, inclusion: { in: [true, false] }

    validate :video_kind_matches_section_type

    private

    def video_kind_matches_section_type
      return if video.nil? || profile_section.nil?
      return if video.kind == profile_section.section_type

      errors.add(:video_id, :invalid)
    end
  end
end
