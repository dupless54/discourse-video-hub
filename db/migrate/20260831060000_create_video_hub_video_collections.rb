# frozen_string_literal: true

class CreateVideoHubVideoCollections < ActiveRecord::Migration[7.0]
  def change
    create_table :video_hub_video_collections do |t|
      t.integer :user_id, null: false
      t.string :collection_type, limit: 20, null: false
      t.string :title, limit: 100, null: false
      t.string :description, limit: 500
      t.integer :position, null: false
      t.boolean :visible, default: false, null: false
      t.timestamps
    end

    add_index :video_hub_video_collections,
              %i[user_id position],
              unique: true,
              name: "idx_video_hub_collections_owner_position"
    add_index :video_hub_video_collections,
              %i[user_id collection_type],
              name: "idx_video_hub_collections_owner_type"
    add_foreign_key :video_hub_video_collections, :users, on_delete: :cascade

    add_check_constraint :video_hub_video_collections,
                         "collection_type IN ('playlist', 'series')",
                         name: "video_hub_collections_type"
    add_check_constraint :video_hub_video_collections,
                         "position >= 0",
                         name: "video_hub_collections_position"

    create_table :video_hub_video_collection_items do |t|
      t.bigint :video_collection_id, null: false
      t.bigint :video_id, null: false
      t.integer :position, null: false
      t.timestamps
    end

    add_index :video_hub_video_collection_items,
              %i[video_collection_id video_id],
              unique: true,
              name: "idx_video_hub_collection_items_collection_video"
    add_index :video_hub_video_collection_items,
              %i[video_collection_id position],
              unique: true,
              name: "idx_video_hub_collection_items_collection_position"

    add_foreign_key :video_hub_video_collection_items,
                    :video_hub_video_collections,
                    column: :video_collection_id,
                    on_delete: :cascade
    add_foreign_key :video_hub_video_collection_items,
                    :video_hub_videos,
                    column: :video_id,
                    on_delete: :cascade

    add_check_constraint :video_hub_video_collection_items,
                         "position >= 0",
                         name: "video_hub_collection_items_position"
  end
end
