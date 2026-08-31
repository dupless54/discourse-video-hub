# frozen_string_literal: true

module VideoHub
  class CollectionManager
    class CollectionError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    CollectionEntry = Struct.new(:collection, :items, keyword_init: true)
    AddResult = Struct.new(:collection, :item, :created, keyword_init: true)

    def self.list(user:)
      new(user: user).list
    end

    def self.create(user:, collection_type:, title:, description: nil)
      new(user: user).create(
        collection_type: collection_type,
        title: title,
        description: description,
      )
    end

    def self.update(user:, collection_id:, attributes:)
      new(user: user).update(collection_id: collection_id, attributes: attributes)
    end

    def self.destroy(user:, collection_id:)
      new(user: user).destroy(collection_id: collection_id)
    end

    def self.add_video(user:, collection_id:, video_id:)
      new(user: user).add_video(collection_id: collection_id, video_id: video_id)
    end

    def self.remove_video(user:, collection_id:, video_id:)
      new(user: user).remove_video(collection_id: collection_id, video_id: video_id)
    end

    def initialize(user:)
      @user = user
      @guardian = Guardian.new(user)
    end

    def list
      owned_collections
        .includes(:items)
        .order(:position, :id)
        .map { |collection| collection_entry(collection, sorted_items(collection.items)) }
        .freeze
    end

    def create(collection_type:, title:, description: nil)
      user.with_lock do
        collections = owned_collections.lock.order(:position, :id).to_a
        collection =
          VideoHub::VideoCollection.create!(
            user: user,
            collection_type: collection_type,
            title: title,
            description: description,
            position: next_position(collections),
            visible: false,
          )

        collection_entry(collection, [])
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique
      raise CollectionError.new(:invalid_collection)
    end

    def update(collection_id:, attributes:)
      collection = owned_collection!(collection_id)
      permitted_attributes = attributes.slice(:title, :description, :visible)
      raise CollectionError.new(:invalid_collection) if permitted_attributes.empty?

      collection.with_lock do
        collection.update!(permitted_attributes)
        collection_entry(collection, locked_items(collection))
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique
      raise CollectionError.new(:invalid_collection)
    end

    def destroy(collection_id:)
      normalized_collection_id = normalize_positive_integer(collection_id)

      user.with_lock do
        collections = owned_collections.lock.order(:position, :id).to_a
        collection = collections.find { |candidate| candidate.id == normalized_collection_id }
        raise Discourse::NotFound unless collection

        collection.destroy!
        compact_positions!(collections.reject { |candidate| candidate.id == collection.id })
        true
      end
    rescue ActiveRecord::RecordInvalid,
           ActiveRecord::RecordNotSaved,
           ActiveRecord::RecordNotDestroyed,
           ActiveRecord::RecordNotUnique
      raise CollectionError.new(:invalid_collection)
    end

    def add_video(collection_id:, video_id:)
      collection = owned_collection!(collection_id)
      normalized_video_id = normalize_positive_integer(video_id)

      collection.with_lock do
        items = locked_items(collection)
        existing_item = items.find { |item| item.video_id == normalized_video_id }
        if existing_item
          return AddResult.new(collection: collection, item: existing_item, created: false).freeze
        end

        video = eligible_video!(normalized_video_id)
        if collection.collection_type == "series" && video.user_id != user.id
          raise CollectionError.new(:series_video_not_owned)
        end

        item =
          VideoHub::VideoCollectionItem.create!(
            video_collection: collection,
            video: video,
            position: next_position(items),
          )

        AddResult.new(collection: collection, item: item, created: true).freeze
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique
      raise CollectionError.new(:invalid_collection)
    end

    def remove_video(collection_id:, video_id:)
      collection = owned_collection!(collection_id)
      normalized_video_id = normalize_positive_integer(video_id)

      collection.with_lock do
        items = locked_items(collection)
        item = items.find { |candidate| candidate.video_id == normalized_video_id }
        return false unless item

        item.destroy!
        compact_positions!(items.reject { |candidate| candidate.id == item.id })
        true
      end
    rescue ActiveRecord::RecordInvalid,
           ActiveRecord::RecordNotSaved,
           ActiveRecord::RecordNotDestroyed,
           ActiveRecord::RecordNotUnique
      raise CollectionError.new(:invalid_collection)
    end

    private

    attr_reader :guardian, :user

    def owned_collections
      VideoHub::VideoCollection.where(user_id: user.id)
    end

    def owned_collection!(collection_id)
      collection = owned_collections.find_by(id: normalize_positive_integer(collection_id))
      raise Discourse::NotFound unless collection

      collection
    end

    def eligible_video!(video_id)
      video = VideoHub::Video.includes(:topic, :post).find_by(id: video_id, status: "published")
      unless VideoHub::WatchQuery.visible_video?(video, guardian: guardian)
        raise Discourse::NotFound
      end

      video
    end

    def locked_items(collection)
      VideoHub::VideoCollectionItem
        .where(video_collection_id: collection.id)
        .lock
        .order(:position, :id)
        .to_a
    end

    def sorted_items(items)
      items.sort_by { |item| [item.position, item.id] }
    end

    def collection_entry(collection, items)
      CollectionEntry.new(collection: collection, items: items.freeze).freeze
    end

    def next_position(records)
      records.empty? ? 0 : records.map(&:position).max + 1
    end

    def compact_positions!(records)
      records.each_with_index do |record, position|
        record.update!(position: position) unless record.position == position
      end
    end

    def normalize_positive_integer(value)
      return value if value.is_a?(Integer) && value.positive?
      return value.to_i if value.is_a?(String) && value.match?(/\A[1-9]\d*\z/)

      raise Discourse::NotFound
    end
  end
end
