# frozen_string_literal: true

class CreateVideoHubDailyMetrics < ActiveRecord::Migration[7.0]
  def change
    create_table :video_hub_daily_metrics do |t|
      t.bigint :video_id, null: false
      t.date :day, null: false
      t.integer :impressions, default: 0, null: false
      t.integer :qualified_views, default: 0, null: false
      t.timestamps
    end

    add_index :video_hub_daily_metrics,
              %i[video_id day],
              unique: true,
              name: "idx_video_hub_daily_metrics_video_day"
    add_index :video_hub_daily_metrics,
              %i[day video_id],
              name: "idx_video_hub_daily_metrics_day_video"

    add_foreign_key :video_hub_daily_metrics,
                    :video_hub_videos,
                    column: :video_id,
                    on_delete: :cascade

    add_check_constraint :video_hub_daily_metrics,
                         "impressions >= 0",
                         name: "video_hub_daily_metrics_impressions"
    add_check_constraint :video_hub_daily_metrics,
                         "qualified_views >= 0",
                         name: "video_hub_daily_metrics_qualified_views"
    add_check_constraint :video_hub_daily_metrics,
                         "qualified_views <= impressions",
                         name: "video_hub_daily_metrics_qualified_lte_impressions"
  end
end
