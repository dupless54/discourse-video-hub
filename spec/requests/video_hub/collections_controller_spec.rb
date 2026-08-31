# frozen_string_literal: true

describe "Video Hub collection management" do
  let(:owner) { Fabricate(:user, trust_level: TrustLevel[2]) }
  let(:category) { Fabricate(:category) }

  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
  end

  it "serves a visible collection publicly with stable owner and video payloads" do
    collection = create_collection(user: owner, collection_type: "playlist", visible: true)
    video = create_video(user: owner)
    item =
      VideoHub::VideoCollectionItem.create!(video_collection: collection, video: video, position: 0)

    get "/videos/collections/#{collection.id}.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body.fetch("collection")).to eq(
      {
        "id" => collection.id,
        "collection_type" => "playlist",
        "title" => "Collection",
        "description" => nil,
        "owner" => {
          "id" => owner.id,
          "username" => owner.username,
          "name" => owner.name,
        },
        "items" => [
          {
            "position" => item.position,
            "video" => {
              "id" => video.id,
              "provider" => "youtube",
              "external_id" => video.external_id,
              "canonical_url" => video.canonical_url,
              "kind" => "landscape",
              "title" => video.title,
              "thumbnail_url" => nil,
              "duration_seconds" => nil,
              "author_name" => "Collection author",
              "published_at" => video.published_at.iso8601,
              "watch_path" => "/videos/#{video.id}/#{video.topic.slug}",
            },
          },
        ],
      },
    )
  end

  it "keeps private collections indistinguishable from missing public collections" do
    collection = create_collection(user: owner, collection_type: "playlist")

    get "/videos/collections/#{collection.id}.json"

    expect(response.status).to eq(404)
  end

  it "returns not found before public collection access when Video Hub is disabled" do
    collection = create_collection(user: owner, collection_type: "playlist", visible: true)
    SiteSetting.video_hub_enabled = false
    VideoHub::CollectionQuery.expects(:fetch).never

    get "/videos/collections/#{collection.id}.json"

    expect(response.status).to eq(404)
  end

  it "requires login before reading or mutating collections" do
    get "/videos/collections.json"
    expect(response.status).to eq(403)

    post "/videos/collections.json",
         params: {
           collection: {
             collection_type: "playlist",
             title: "Anonymous",
           },
         }

    expect(response.status).to eq(403)
    expect(VideoHub::VideoCollection.count).to eq(0)

    put "/videos/collections/reorder.json", params: { collection_ids: [] }
    expect(response.status).to eq(403)

    put "/videos/collections/1/items/reorder.json", params: { item_ids: [] }
    expect(response.status).to eq(403)
  end

  it "creates, updates, lists, and destroys an owner collection" do
    sign_in(owner)

    post "/videos/collections.json",
         params: {
           collection: {
             collection_type: "playlist",
             title: "Favorites",
             description: "My favorite videos",
           },
         }

    expect(response.status).to eq(201)
    collection_id = response.parsed_body.dig("collection", "id")
    expect(response.parsed_body.fetch("collection")).to include(
      "collection_type" => "playlist",
      "title" => "Favorites",
      "description" => "My favorite videos",
      "position" => 0,
      "visible" => false,
      "items" => [],
    )

    put "/videos/collections/#{collection_id}.json",
        params: {
          collection: {
            title: "Public favorites",
            description: "Updated",
            visible: true,
            collection_type: "series",
          },
        }

    expect(response.status).to eq(200)
    expect(response.parsed_body.fetch("collection")).to include(
      "collection_type" => "playlist",
      "title" => "Public favorites",
      "description" => "Updated",
      "visible" => true,
    )

    get "/videos/collections.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body.fetch("collections").map { |entry| entry.fetch("id") }).to eq(
      [collection_id],
    )

    delete "/videos/collections/#{collection_id}.json"

    expect(response.status).to eq(204)
    expect(VideoHub::VideoCollection.exists?(collection_id)).to eq(false)
  end

  it "adds and removes a visible canonical video with idempotent membership semantics" do
    collection = create_collection(user: owner, collection_type: "playlist")
    video = create_video(user: Fabricate(:user))
    sign_in(owner)

    put "/videos/collections/#{collection.id}/videos/#{video.id}.json"

    expect(response.status).to eq(201)
    item_id = response.parsed_body.dig("membership", "item_id")
    expect(response.parsed_body.fetch("membership")).to eq(
      {
        "collection_id" => collection.id,
        "item_id" => item_id,
        "video_id" => video.id,
        "position" => 0,
      },
    )

    put "/videos/collections/#{collection.id}/videos/#{video.id}.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("membership", "item_id")).to eq(item_id)
    expect(collection.items.count).to eq(1)

    get "/videos/collections.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("collections", 0, "items")).to eq(
      [
        {
          "id" => item_id,
          "video_id" => video.id,
          "position" => 0,
          "video" => {
            "id" => video.id,
            "provider" => "youtube",
            "external_id" => video.external_id,
            "canonical_url" => video.canonical_url,
            "kind" => "landscape",
            "title" => video.title,
            "thumbnail_url" => nil,
            "duration_seconds" => nil,
            "author_name" => "Collection author",
            "published_at" => video.published_at.iso8601,
            "watch_path" => "/videos/#{video.id}/#{video.topic.slug}",
          },
        },
      ],
    )

    delete "/videos/collections/#{collection.id}/videos/#{video.id}.json"
    expect(response.status).to eq(204)

    delete "/videos/collections/#{collection.id}/videos/#{video.id}.json"
    expect(response.status).to eq(204)
  end

  it "keeps hidden memberships removable without exposing hidden video metadata" do
    collection = create_collection(user: owner, collection_type: "playlist")
    video = create_video(user: Fabricate(:user))
    item =
      VideoHub::VideoCollectionItem.create!(video_collection: collection, video: video, position: 0)
    video.post.update_column(:hidden, true)
    sign_in(owner)

    get "/videos/collections.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("collections", 0, "items", 0)).to eq(
      { "id" => item.id, "video_id" => video.id, "position" => 0, "video" => nil },
    )
  end

  it "reorders all owner collections and returns the authoritative id order" do
    first = create_collection(user: owner, title: "First", position: 0)
    second = create_collection(user: owner, title: "Second", position: 1)
    third = create_collection(user: owner, title: "Third", position: 2)
    ordered_ids = [third.id, first.id, second.id]
    sign_in(owner)

    put "/videos/collections/reorder.json", params: { collection_ids: ordered_ids }

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq({ "collection_ids" => ordered_ids })
    expect(
      VideoHub::VideoCollection.where(user_id: owner.id).order(:position).pluck(:id, :position),
    ).to eq([[third.id, 0], [first.id, 1], [second.id, 2]])

    get "/videos/collections.json"
    expect(response.parsed_body.fetch("collections").map { |entry| entry.fetch("id") }).to eq(
      ordered_ids,
    )
  end

  it "reorders all memberships in one owned collection by membership id" do
    collection = create_collection(user: owner)
    videos = Array.new(3) { create_video(user: Fabricate(:user)) }
    items =
      videos.each_with_index.map do |video, position|
        VideoHub::VideoCollectionItem.create!(
          video_collection: collection,
          video: video,
          position: position,
        )
      end
    ordered_ids = [items[2].id, items[0].id, items[1].id]
    sign_in(owner)

    put "/videos/collections/#{collection.id}/items/reorder.json", params: { item_ids: ordered_ids }

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq({ "item_ids" => ordered_ids })
    expect(collection.items.order(:position).pluck(:id, :position)).to eq(
      [[items[2].id, 0], [items[0].id, 1], [items[1].id, 2]],
    )

    get "/videos/collections.json"
    expect(response.parsed_body.dig("collections", 0, "items").map { |item| item.fetch("id") }).to eq(
      ordered_ids,
    )
  end

  it "rejects non-exact reorder permutations without partial writes" do
    first = create_collection(user: owner, title: "First", position: 0)
    second = create_collection(user: owner, title: "Second", position: 1)
    foreign = create_collection(user: Fabricate(:user), title: "Foreign", position: 0)
    collection_positions =
      VideoHub::VideoCollection.where(user_id: owner.id).order(:position).pluck(:id, :position)

    collection = first
    videos = Array.new(2) { create_video(user: Fabricate(:user)) }
    items =
      videos.each_with_index.map do |video, position|
        VideoHub::VideoCollectionItem.create!(
          video_collection: collection,
          video: video,
          position: position,
        )
      end
    another_collection = create_collection(user: owner, title: "Another", position: 2)
    foreign_item =
      VideoHub::VideoCollectionItem.create!(
        video_collection: another_collection,
        video: create_video(user: Fabricate(:user)),
        position: 0,
      )
    item_positions = collection.items.order(:position).pluck(:id, :position)
    sign_in(owner)

    put "/videos/collections/reorder.json", params: { collection_ids: [first.id, foreign.id] }

    expect(response.status).to eq(422)
    expect(response.parsed_body).to eq({ "error" => { "code" => "invalid_collection_order" } })
    expect(
      VideoHub::VideoCollection.where(user_id: owner.id).order(:position).pluck(:id, :position),
    ).to eq(collection_positions + [[another_collection.id, 2]])

    put "/videos/collections/#{collection.id}/items/reorder.json",
        params: {
          item_ids: [items[0].id, foreign_item.id],
        }

    expect(response.status).to eq(422)
    expect(response.parsed_body).to eq({ "error" => { "code" => "invalid_item_order" } })
    expect(collection.items.order(:position).pluck(:id, :position)).to eq(item_positions)
  end

  it "keeps foreign collection reorder targets fail-closed" do
    foreign_collection = create_collection(user: Fabricate(:user))
    sign_in(owner)

    put "/videos/collections/#{foreign_collection.id}/items/reorder.json", params: { item_ids: [] }

    expect(response.status).to eq(404)
  end

  it "maps a foreign video added to a series to a bounded validation error" do
    collection = create_collection(user: owner, collection_type: "series")
    video = create_video(user: Fabricate(:user))
    sign_in(owner)

    put "/videos/collections/#{collection.id}/videos/#{video.id}.json"

    expect(response.status).to eq(422)
    expect(response.parsed_body).to eq({ "error" => { "code" => "series_video_not_owned" } })
    expect(collection.items).to be_empty
  end

  it "fails closed when another user targets an owner's collection" do
    collection = create_collection(user: owner, collection_type: "playlist")
    other_user = Fabricate(:user)
    sign_in(other_user)

    put "/videos/collections/#{collection.id}.json",
        params: {
          collection: {
            title: "Unauthorized",
          },
        }

    expect(response.status).to eq(404)
    expect(collection.reload.title).to eq("Collection")

    get "/videos/collections.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq({ "collections" => [] })
  end

  it "returns not found before collection access when Video Hub is disabled" do
    sign_in(owner)
    SiteSetting.video_hub_enabled = false
    VideoHub::CollectionManager.expects(:list).never
    VideoHub::CollectionManager.expects(:reorder_collections).never

    get "/videos/collections.json"
    expect(response.status).to eq(404)

    put "/videos/collections/reorder.json", params: { collection_ids: [] }
    expect(response.status).to eq(404)
  end

  def create_collection(
    user:,
    collection_type: "playlist",
    visible: false,
    position: 0,
    title: "Collection"
  )
    VideoHub::VideoCollection.create!(
      user: user,
      collection_type: collection_type,
      title: title,
      position: position,
      visible: visible,
    )
  end

  def create_video(user:)
    @video_sequence = @video_sequence.to_i + 1
    topic = Fabricate(:topic, user: user, category: category)
    post = Fabricate(:post, topic: topic, user: user)

    VideoHub::Video.create!(
      user: user,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: "collection-request-#{@video_sequence}",
      canonical_url: "https://example.com/collection-request-#{@video_sequence}",
      kind: "landscape",
      title: "Collection request #{@video_sequence}",
      author_name: "Collection author",
      status: "published",
      published_at: Time.zone.now,
    )
  end
end
