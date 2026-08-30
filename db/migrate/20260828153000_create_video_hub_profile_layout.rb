# frozen_string_literal: true

class CreateVideoHubProfileLayout < ActiveRecord::Migration[7.0]
  def change
    create_table :video_hub_profile_sections do |t|
      t.integer :user_id, null: false
      t.string :section_type, limit: 20, null: false
      t.string :title, limit: 100
      t.integer :position, null: false
      t.boolean :visible, default: true, null: false
      t.timestamps
    end

    add_index :video_hub_profile_sections, %i[user_id section_type], unique: true
    add_index :video_hub_profile_sections, %i[user_id position], unique: true
    add_foreign_key :video_hub_profile_sections, :users, on_delete: :cascade

    add_check_constraint :video_hub_profile_sections,
                         "section_type IN ('shorts', 'landscape')",
                         name: "video_hub_profile_sections_type"
    add_check_constraint :video_hub_profile_sections,
                         "position >= 0",
                         name: "video_hub_profile_sections_position"

    create_table :video_hub_profile_items do |t|
      t.bigint :profile_section_id, null: false
      t.bigint :video_id, null: false
      t.integer :position, null: false
      t.boolean :pinned, default: false, null: false
      t.boolean :visible, default: true, null: false
      t.timestamps
    end

    add_index :video_hub_profile_items,
              %i[profile_section_id video_id],
              unique: true,
              name: "idx_video_hub_profile_items_section_video"
    add_index :video_hub_profile_items,
              %i[profile_section_id position],
              unique: true,
              name: "idx_video_hub_profile_items_section_position"

    add_foreign_key :video_hub_profile_items,
                    :video_hub_profile_sections,
                    column: :profile_section_id,
                    on_delete: :cascade
    add_foreign_key :video_hub_profile_items,
                    :video_hub_videos,
                    column: :video_id,
                    on_delete: :cascade

    add_check_constraint :video_hub_profile_items,
                         "position >= 0",
                         name: "video_hub_profile_items_position"
  end
end
