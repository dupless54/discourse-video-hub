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

    def self.reorder_collections(user:, collection_ids:)
      new(user: user).reorder_collections(collection_ids: collection_ids)
    end

    def self.reorder_items(user:, collection_id:, item_ids:)
      new(user: user).reorder_items(collection_id: collection_id, item_ids: item_ids)
    end

    def initialize(user:)
      @user = user
      @guardian = Guardian.new(user)
    end

    def list
      owned_collections
        .includes(items: { video: %i[topic post] })
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

    def reorder_collections(collection_ids:)
      normalized_ids = normalize_order_ids(collection_ids, :invalid_collection_order)

      user.with_lock do
        collections = owned_collections.lock.order(:position, :id).to_a
        validate_exact_order!(normalized_ids, collections.map(&:id), :invalid_collection_order)
        rewrite_positions!(collections, normalized_ids)
        normalized_ids.freeze
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique
      raise CollectionError.new(:invalid_collection_order)
    end

    def reorder_items(collection_id:, item_ids:)
      collection = owned_collection!(collection_id)
      normalized_ids = normalize_order_ids(item_ids, :invalid_item_order)

      collection.with_lock do
        items = locked_items(collection)
        validate_exact_order!(normalized_ids, items.map(&:id), :invalid_item_order)
        rewrite_positions!(items, normalized_ids)
        normalized_ids.freeze
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique
      raise CollectionError.new(:invalid_item_order)
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
        .includes(video: %i[topic post])
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

    def rewrite_positions!(records, ordered_ids)
      current_ids = records.sort_by { |record| [record.position, record.id] }.map(&:id)
      return if current_ids == ordered_ids || records.empty?

      temporary_offset = records.map(&:position).max + records.length + 1
      record_class = records.first.class
      record_class
        .where(id: records.map(&:id))
        .update_all(position: Arel.sql("position + #{temporary_offset}"))
      records.each { |record| record.position += temporary_offset }

      records_by_id = records.index_by(&:id)
      ordered_ids.each_with_index do |id, position|
        records_by_id.fetch(id).update!(position: position)
      end
    end

    def validate_exact_order!(ordered_ids, existing_ids, error_code)
      return if ordered_ids.length == existing_ids.length && ordered_ids.sort == existing_ids.sort

      raise CollectionError.new(error_code)
    end

    def normalize_order_ids(values, error_code)
      raise CollectionError.new(error_code) unless values.is_a?(Array)

      ids = values.map { |value| normalize_order_integer(value, error_code) }
      raise CollectionError.new(error_code) unless ids.uniq.length == ids.length

      ids
    end

    def normalize_order_integer(value, error_code)
      return value if value.is_a?(Integer) && value.positive?
      return value.to_i if value.is_a?(String) && value.match?(/\A[1-9]\d*\z/)

      raise CollectionError.new(error_code)
    end

    def normalize_positive_integer(value)
      return value if value.is_a?(Integer) && value.positive?
      return value.to_i if value.is_a?(String) && value.match?(/\A[1-9]\d*\z/)

      raise Discourse::NotFound
    end
  end
end
