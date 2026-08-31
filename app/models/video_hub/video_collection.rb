# frozen_string_literal: true

module VideoHub
  class VideoCollection < ActiveRecord::Base
    COLLECTION_TYPES = %w[playlist series].freeze
    TITLE_MAX_LENGTH = 100
    DESCRIPTION_MAX_LENGTH = 500

    belongs_to :user

    has_many :items,
             class_name: "VideoHub::VideoCollectionItem",
             foreign_key: :video_collection_id,
             inverse_of: :video_collection,
             dependent: :destroy

    validates :collection_type, inclusion: { in: COLLECTION_TYPES }
    validates :title, presence: true, length: { maximum: TITLE_MAX_LENGTH }
    validates :description, length: { maximum: DESCRIPTION_MAX_LENGTH }, allow_nil: true
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
# Table name: video_hub_video_collections
#
#  id              :bigint           not null, primary key
#  collection_type :string(20)       not null
#  description     :string(500)
#  position        :integer          not null
#  title           :string(100)      not null
#  visible         :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :integer          not null
#
# Indexes
#
#  idx_video_hub_collections_owner_position  (user_id,position) UNIQUE
#  idx_video_hub_collections_owner_type      (user_id,collection_type)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
