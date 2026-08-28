# frozen_string_literal: true

module VideoHub
  class ProfileItem < ActiveRecord::Base
    belongs_to :profile_section, class_name: "VideoHub::ProfileSection", inverse_of: :items
    belongs_to :video, class_name: "VideoHub::Video"

    validates :video_id, uniqueness: { scope: :profile_section_id }
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

# == Schema Information
#
# Table name: video_hub_profile_items
#
#  id                 :bigint           not null, primary key
#  pinned             :boolean          default(FALSE), not null
#  position           :integer          not null
#  visible            :boolean          default(TRUE), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  profile_section_id :bigint           not null
#  video_id           :bigint           not null
#
# Indexes
#
#  idx_video_hub_profile_items_section_position  (profile_section_id,position) UNIQUE
#  idx_video_hub_profile_items_section_video     (profile_section_id,video_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (profile_section_id => video_hub_profile_sections.id) ON DELETE => cascade
#  fk_rails_...  (video_id => video_hub_videos.id) ON DELETE => cascade
#
