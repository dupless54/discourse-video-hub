# frozen_string_literal: true

module VideoHub
  class DailyMetric < ActiveRecord::Base
    RETENTION_DAYS = 90

    belongs_to :video, class_name: "VideoHub::Video"

    validates :day, presence: true, uniqueness: { scope: :video_id }
    validates :impressions, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :qualified_views,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: :impressions,
              }
  end
end

# == Schema Information
#
# Table name: video_hub_daily_metrics
#
#  id              :bigint           not null, primary key
#  day             :date             not null
#  impressions     :integer          default(0), not null
#  qualified_views :integer          default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  video_id        :bigint           not null
#
# Indexes
#
#  idx_video_hub_daily_metrics_day_video  (day,video_id)
#  idx_video_hub_daily_metrics_video_day  (video_id,day) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (video_id => video_hub_videos.id) ON DELETE => cascade
#
