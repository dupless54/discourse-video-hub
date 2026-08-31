# frozen_string_literal: true

module VideoHub
  class CollectionQuery
    PROVIDER_SETTINGS = {
      "youtube" => :video_hub_youtube_enabled,
      "tiktok" => :video_hub_tiktok_enabled,
      "instagram" => :video_hub_instagram_enabled,
    }.freeze

    ItemResult = Struct.new(:collection_item, :video, keyword_init: true)
    Result = Struct.new(:collection, :owner, :items, keyword_init: true)

    def self.fetch(user:, id:)
      new(user:, id:).fetch
    end

    def initialize(user:, id:)
      @guardian = Guardian.new(user)
      @id = parse_id(id)
    end

    def fetch
      collection = VideoHub::VideoCollection.includes(:user).find_by(id: id, visible: true)
      raise Discourse::NotFound unless collection && guardian.can_see_profile?(collection.user)

      items =
        candidate_items(collection).filter_map do |collection_item|
          video = collection_item.video
          next unless VideoHub::WatchQuery.visible_video?(video, guardian: guardian)

          ItemResult.new(collection_item: collection_item, video: video).freeze
        end

      Result.new(collection: collection, owner: collection.user, items: items.freeze).freeze
    end

    private

    attr_reader :guardian, :id

    def candidate_items(collection)
      VideoHub::VideoCollectionItem
        .joins(video: %i[topic post])
        .includes(video: %i[topic post])
        .where(video_collection_id: collection.id)
        .where(
          video_hub_videos: {
            status: "published",
            provider: enabled_providers,
          },
          topics: {
            category_id: guardian.allowed_category_ids,
            deleted_at: nil,
            visible: true,
          },
          posts: {
            deleted_at: nil,
            hidden: false,
          },
        )
        .where.not(video_hub_videos: { published_at: nil })
        .order(position: :asc, id: :asc)
        .to_a
    end

    def enabled_providers
      PROVIDER_SETTINGS.filter_map do |provider, setting|
        provider if SiteSetting.public_send(setting)
      end
    end

    def parse_id(value)
      raw_id = value.to_s
      raise Discourse::NotFound unless raw_id.match?(/\A[1-9][0-9]*\z/)

      id = raw_id.to_i
      raise Discourse::NotFound if id > VideoHub::WatchQuery::MAX_RECORD_ID

      id
    end
  end
end
