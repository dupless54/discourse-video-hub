# frozen_string_literal: true

class CreateVideoHubVideos < ActiveRecord::Migration[7.0]
  def change
    create_table :video_hub_videos do |t|
      t.integer :user_id
      t.integer :topic_id
      t.integer :post_id
      t.string :provider, limit: 20, null: false
      t.string :external_id, limit: 64, null: false
      t.string :canonical_url, limit: 2048, null: false
      t.string :kind, limit: 20, null: false
      t.string :title, limit: 300
      t.text :description
      t.string :thumbnail_url, limit: 2048
      t.integer :duration_seconds
      t.string :author_name, limit: 200
      t.string :status, limit: 20, default: "pending", null: false
      t.datetime :published_at
      t.timestamps
    end

    add_index :video_hub_videos, %i[provider external_id], unique: true
    add_index :video_hub_videos, :topic_id, unique: true
    add_index :video_hub_videos, :post_id, unique: true
    add_index :video_hub_videos, %i[status published_at id]
    add_index :video_hub_videos,
              %i[user_id status published_at id],
              name: "idx_video_hub_author_feed"

    add_foreign_key :video_hub_videos, :users, on_delete: :nullify
    add_foreign_key :video_hub_videos, :topics, on_delete: :cascade
    add_foreign_key :video_hub_videos, :posts, on_delete: :cascade

    add_check_constraint :video_hub_videos,
                         "provider IN ('youtube', 'tiktok', 'instagram')",
                         name: "video_hub_videos_provider"
    add_check_constraint :video_hub_videos,
                         "kind IN ('shorts', 'landscape')",
                         name: "video_hub_videos_kind"
    add_check_constraint :video_hub_videos,
                         "status IN ('pending', 'published', 'unavailable')",
                         name: "video_hub_videos_status"
    add_check_constraint :video_hub_videos,
                         "duration_seconds IS NULL OR duration_seconds >= 0",
                         name: "video_hub_videos_duration"
    add_check_constraint :video_hub_videos,
                         "(topic_id IS NULL AND post_id IS NULL) OR (topic_id IS NOT NULL AND post_id IS NOT NULL)",
                         name: "video_hub_videos_mapping_pair"
    add_check_constraint :video_hub_videos,
                         "status <> 'published' OR (topic_id IS NOT NULL AND post_id IS NOT NULL AND published_at IS NOT NULL)",
                         name: "video_hub_videos_published_mapping"
  end
end
