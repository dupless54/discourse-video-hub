# frozen_string_literal: true

module VideoHub
  class CollectionCatalogQuery
    DEFAULT_LIMIT = 20
    MAX_SCAN_ROWS = 200

    Result = Struct.new(:collection, :videos, :has_more, :next_cursor, keyword_init: true)

    class CatalogError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    def self.fetch(user:, collection_id:, cursor: nil, limit: DEFAULT_LIMIT)
      new(user: user, collection_id: collection_id, cursor: cursor, limit: limit).fetch
    end

    def initialize(user:, collection_id:, cursor:, limit:)
      @user = user
      @guardian = Guardian.new(user)
      @collection_id = normalize_positive_integer(collection_id)
      @cursor_id = normalize_cursor(cursor)
      @limit = Integer(limit)
    rescue ArgumentError, TypeError
      raise CatalogError.new(:invalid_limit)
    end

    def fetch
      raise CatalogError.new(:invalid_limit) unless limit.between?(1, DEFAULT_LIMIT)

      collection = owned_collection!
      scanned = candidate_scope(collection).limit(MAX_SCAN_ROWS).to_a
      visible =
        scanned.select { |video| VideoHub::WatchQuery.visible_video?(video, guardian: guardian) }
      page = visible.first(limit)

      has_more, next_cursor = pagination_for(scanned, visible, page)

      Result.new(
        collection: collection,
        videos: page.freeze,
        has_more: has_more,
        next_cursor: next_cursor,
      ).freeze
    end

    private

    attr_reader :collection_id, :cursor_id, :guardian, :limit, :user

    def owned_collection!
      collection = VideoHub::VideoCollection.find_by(id: collection_id, user_id: user.id)
      raise Discourse::NotFound unless collection

      collection
    end

    def candidate_scope(collection)
      scope =
        VideoHub::Video
          .joins(:topic, :post)
          .includes(:topic, :post)
          .where(status: "published", provider: enabled_providers)
          .where.not(published_at: nil)
          .where.not(
            id:
              VideoHub::VideoCollectionItem.where(video_collection_id: collection.id).select(
                :video_id,
              ),
          )
          .where(
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

      scope = scope.where(user_id: user.id) if collection.collection_type == "series"
      scope = scope.where("video_hub_videos.id < ?", cursor_id) if cursor_id
      scope.order(id: :desc)
    end

    def enabled_providers
      VideoHub::FeedQuery::PROVIDER_SETTINGS.filter_map do |provider, setting|
        provider if SiteSetting.public_send(setting)
      end
    end

    def pagination_for(scanned, visible, page)
      if visible.length > limit
        [true, page.last.id.to_s]
      elsif scanned.length == MAX_SCAN_ROWS
        [true, scanned.last.id.to_s]
      else
        [false, nil]
      end
    end

    def normalize_cursor(value)
      return if value.blank?
      return value if value.is_a?(Integer) && value.positive?
      return value.to_i if value.is_a?(String) && value.match?(/\A[1-9]\d*\z/)

      raise CatalogError.new(:invalid_cursor)
    end

    def normalize_positive_integer(value)
      return value if value.is_a?(Integer) && value.positive?
      return value.to_i if value.is_a?(String) && value.match?(/\A[1-9]\d*\z/)

      raise Discourse::NotFound
    end
  end
end
