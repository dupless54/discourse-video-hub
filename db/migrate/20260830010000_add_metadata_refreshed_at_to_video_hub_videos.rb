# frozen_string_literal: true

class AddMetadataRefreshedAtToVideoHubVideos < ActiveRecord::Migration[7.0]
  def change
    add_column :video_hub_videos, :metadata_refreshed_at, :datetime
    add_index :video_hub_videos,
              %i[status metadata_refreshed_at id],
              name: "idx_video_hub_metadata_refresh"
  end
end
