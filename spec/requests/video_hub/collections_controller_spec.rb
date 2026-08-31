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
      [{ "id" => item_id, "video_id" => video.id, "position" => 0 }],
    )

    delete "/videos/collections/#{collection.id}/videos/#{video.id}.json"
    expect(response.status).to eq(204)

    delete "/videos/collections/#{collection.id}/videos/#{video.id}.json"
    expect(response.status).to eq(204)
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

    get "/videos/collections.json"

    expect(response.status).to eq(404)
  end

  def create_collection(user:, collection_type:, visible: false)
    VideoHub::VideoCollection.create!(
      user: user,
      collection_type: collection_type,
      title: "Collection",
      position: 0,
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
