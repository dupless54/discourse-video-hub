# frozen_string_literal: true

module VideoHub
  class VideoCollectionItem < ActiveRecord::Base
    belongs_to :video_collection, class_name: "VideoHub::VideoCollection", inverse_of: :items
    belongs_to :video, class_name: "VideoHub::Video"

    validates :video_id, uniqueness: { scope: :video_collection_id }
    validates :position,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
              },
              uniqueness: {
                scope: :video_collection_id,
              }

    validate :series_video_owned_by_collection_owner

    private

    def series_video_owned_by_collection_owner
      return if video_collection.nil? || video.nil?
      return unless video_collection.collection_type == "series"
      return if video.user_id == video_collection.user_id

      errors.add(:video_id, :invalid)
    end
  end
end

# == Schema Information
#
# Table name: video_hub_video_collection_items
#
#  id                  :bigint           not null, primary key
#  position            :integer          not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  video_collection_id :bigint           not null
#  video_id            :bigint           not null
#
# Indexes
#
#  idx_video_hub_collection_items_collection_position  (video_collection_id,position) UNIQUE
#  idx_video_hub_collection_items_collection_video     (video_collection_id,video_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (video_collection_id => video_hub_video_collections.id) ON DELETE => cascade
#  fk_rails_...  (video_id => video_hub_videos.id) ON DELETE => cascade
#
