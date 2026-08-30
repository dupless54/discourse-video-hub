# frozen_string_literal: true

module VideoHub
  class ProfileSection < ActiveRecord::Base
    SECTION_TYPES = %w[shorts landscape].freeze
    TITLE_MAX_LENGTH = 100

    belongs_to :user

    has_many :items,
             class_name: "VideoHub::ProfileItem",
             foreign_key: :profile_section_id,
             inverse_of: :profile_section,
             dependent: :destroy

    validates :section_type, inclusion: { in: SECTION_TYPES }, uniqueness: { scope: :user_id }
    validates :title, length: { maximum: TITLE_MAX_LENGTH }, allow_nil: true
    validates :position,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
              },
              uniqueness: {
                scope: :user_id,
              }
    validates :visible, inclusion: { in: [true, false] }
  end
end

# == Schema Information
#
# Table name: video_hub_profile_sections
#
#  id           :bigint           not null, primary key
#  position     :integer          not null
#  section_type :string(20)       not null
#  title        :string(100)
#  visible      :boolean          default(TRUE), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :integer          not null
#
# Indexes
#
#  index_video_hub_profile_sections_on_user_id_and_position      (user_id,position) UNIQUE
#  index_video_hub_profile_sections_on_user_id_and_section_type  (user_id,section_type) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
