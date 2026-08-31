# frozen_string_literal: true

describe "Video Hub collection catalog" do
  let(:owner) { Fabricate(:user, trust_level: TrustLevel[2]) }
  let(:category) { Fabricate(:category) }

  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
  end

  it "requires login before exposing an owner collection catalog" do
    collection = create_collection(user: owner)

    get "/videos/collections/#{collection.id}/catalog.json"

    expect(response.status).to eq(403)
  end

  it "returns visible playlist candidates while excluding existing and hidden videos" do
    collection = create_collection(user: owner)
    existing_video = create_video(user: owner)
    candidate_video = create_video(user: Fabricate(:user))
    hidden_video = create_video(user: Fabricate(:user))
    VideoHub::VideoCollectionItem.create!(
      video_collection: collection,
      video: existing_video,
      position: 0,
    )
    hidden_video.post.update_column(:hidden, true)
    sign_in(owner)

    get "/videos/collections/#{collection.id}/catalog.json", params: { limit: 20 }

    expect(response.status).to eq(200)
    expect(response.parsed_body.fetch("collection")).to eq(
      { "id" => collection.id, "collection_type" => "playlist" },
    )
    expect(response.parsed_body.fetch("videos").map { |video| video.fetch("id") }).to eq(
      [candidate_video.id],
    )
    expect(response.parsed_body.fetch("videos").first).to include(
      "title" => candidate_video.title,
      "watch_path" => "/videos/#{candidate_video.id}/#{candidate_video.topic.slug}",
    )
    expect(response.parsed_body.fetch("pagination")).to eq(
      { "has_more" => false, "next_cursor" => nil },
    )
  end

  it "limits series candidates to the collection owner's canonical videos" do
    collection = create_collection(user: owner, collection_type: "series")
    owner_video = create_video(user: owner)
    create_video(user: Fabricate(:user))
    sign_in(owner)

    get "/videos/collections/#{collection.id}/catalog.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body.fetch("videos").map { |video| video.fetch("id") }).to eq(
      [owner_video.id],
    )
  end

  it "keeps foreign collection catalogs fail-closed" do
    collection = create_collection(user: Fabricate(:user))
    sign_in(owner)

    get "/videos/collections/#{collection.id}/catalog.json"

    expect(response.status).to eq(404)
  end

  it "maps malformed catalog pagination to bounded errors" do
    collection = create_collection(user: owner)
    sign_in(owner)

    get "/videos/collections/#{collection.id}/catalog.json", params: { cursor: "bad" }

    expect(response.status).to eq(400)
    expect(response.parsed_body).to eq({ "error" => { "code" => "invalid_cursor" } })

    get "/videos/collections/#{collection.id}/catalog.json", params: { limit: 21 }

    expect(response.status).to eq(400)
    expect(response.parsed_body).to eq({ "error" => { "code" => "invalid_limit" } })
  end

  def create_collection(user:, collection_type: "playlist")
    VideoHub::VideoCollection.create!(
      user: user,
      collection_type: collection_type,
      title: "Catalog collection",
      position: 0,
      visible: false,
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
      external_id: "collection-catalog-request-#{@video_sequence}",
      canonical_url: "https://example.com/collection-catalog-request-#{@video_sequence}",
      kind: "landscape",
      title: "Catalog request #{@video_sequence}",
      author_name: "Catalog author",
      status: "published",
      published_at: Time.zone.now,
    )
  end
end
