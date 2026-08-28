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

    validates :section_type,
              inclusion: {
                in: SECTION_TYPES,
              },
              uniqueness: {
                scope: :user_id,
              }
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
