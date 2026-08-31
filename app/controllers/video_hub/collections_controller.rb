# frozen_string_literal: true

module VideoHub
  class CollectionsController < ::ApplicationController
    requires_plugin VideoHub::PLUGIN_NAME

    before_action :ensure_video_hub_enabled
    before_action :ensure_logged_in, except: :show

    def show
      result = VideoHub::CollectionQuery.fetch(user: current_user, id: params[:id])

      render json: { collection: public_collection_payload(result) }
    end

    def index
      entries = VideoHub::CollectionManager.list(user: current_user)

      render json: { collections: entries.map { |entry| collection_payload(entry) } }
    end

    def create
      attributes = create_params.to_h.symbolize_keys
      entry = VideoHub::CollectionManager.create(user: current_user, **attributes)

      render json: { collection: collection_payload(entry) }, status: :created
    rescue VideoHub::CollectionManager::CollectionError => error
      render_collection_error(error)
    end

    def update
      entry =
        VideoHub::CollectionManager.update(
          user: current_user,
          collection_id: params[:id],
          attributes: update_params.to_h.symbolize_keys,
        )

      render json: { collection: collection_payload(entry) }
    rescue VideoHub::CollectionManager::CollectionError => error
      render_collection_error(error)
    end

    def destroy
      VideoHub::CollectionManager.destroy(user: current_user, collection_id: params[:id])
      head :no_content
    rescue VideoHub::CollectionManager::CollectionError => error
      render_collection_error(error)
    end

    def add_video
      result =
        VideoHub::CollectionManager.add_video(
          user: current_user,
          collection_id: params[:id],
          video_id: params[:video_id],
        )

      render json: {
               membership: membership_payload(result),
             },
             status: result.created ? :created : :ok
    rescue VideoHub::CollectionManager::CollectionError => error
      render_collection_error(error)
    end

    def remove_video
      VideoHub::CollectionManager.remove_video(
        user: current_user,
        collection_id: params[:id],
        video_id: params[:video_id],
      )

      head :no_content
    rescue VideoHub::CollectionManager::CollectionError => error
      render_collection_error(error)
    end

    private

    def ensure_video_hub_enabled
      raise Discourse::NotFound unless SiteSetting.video_hub_enabled
    end

    def create_params
      params.require(:collection).permit(:collection_type, :title, :description)
    end

    def update_params
      params.require(:collection).permit(:title, :description, :visible)
    end

    def public_collection_payload(result)
      collection = result.collection

      {
        id: collection.id,
        collection_type: collection.collection_type,
        title: collection.title,
        description: collection.description,
        owner: {
          id: result.owner.id,
          username: result.owner.username,
          name: result.owner.name,
        },
        items: result.items.map { |item| public_item_payload(item) },
      }
    end

    def public_item_payload(item)
      {
        position: item.collection_item.position,
        video: public_video_payload(item.video),
      }
    end

    def public_video_payload(video)
      {
        id: video.id,
        provider: video.provider,
        external_id: video.external_id,
        canonical_url: video.canonical_url,
        kind: video.kind,
        title: video.title,
        thumbnail_url: video.thumbnail_url,
        duration_seconds: video.duration_seconds,
        author_name: video.author_name,
        published_at: video.published_at&.iso8601,
        watch_path: "/videos/#{video.id}/#{video.topic.slug}",
      }
    end

    def collection_payload(entry)
      collection = entry.collection

      {
        id: collection.id,
        collection_type: collection.collection_type,
        title: collection.title,
        description: collection.description,
        position: collection.position,
        visible: collection.visible,
        items: entry.items.map { |item| item_payload(item) },
      }
    end

    def item_payload(item)
      { id: item.id, video_id: item.video_id, position: item.position }
    end

    def membership_payload(result)
      {
        collection_id: result.collection.id,
        item_id: result.item.id,
        video_id: result.item.video_id,
        position: result.item.position,
      }
    end

    def render_collection_error(error)
      render json: { error: { code: error.code.to_s } }, status: :unprocessable_entity
    end
  end
end
