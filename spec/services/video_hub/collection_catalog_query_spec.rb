# frozen_string_literal: true

describe VideoHub::CollectionCatalogQuery do
  let(:owner) { Fabricate(:user, trust_level: TrustLevel[2]) }
  let(:category) { Fabricate(:category) }

  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
  end

  it "returns visible playlist candidates and excludes existing memberships" do
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

    result = described_class.fetch(user: owner, collection_id: collection.id)

    expect(result.collection).to eq(collection)
    expect(result.videos.map(&:id)).to eq([candidate_video.id])
    expect(result.has_more).to eq(false)
    expect(result.next_cursor).to be_nil
  end

  it "returns only owner videos for a series" do
    collection = create_collection(user: owner, collection_type: "series")
    owner_video = create_video(user: owner)
    create_video(user: Fabricate(:user))

    result = described_class.fetch(user: owner, collection_id: collection.id)

    expect(result.videos.map(&:id)).to eq([owner_video.id])
  end

  it "paginates candidates with a stable descending id cursor" do
    collection = create_collection(user: owner)
    videos = Array.new(3) { create_video(user: Fabricate(:user)) }

    first_page = described_class.fetch(user: owner, collection_id: collection.id, limit: 1)
    second_page =
      described_class.fetch(
        user: owner,
        collection_id: collection.id,
        cursor: first_page.next_cursor,
        limit: 1,
      )

    expect(first_page.videos.map(&:id)).to eq([videos.last.id])
    expect(first_page.has_more).to eq(true)
    expect(first_page.next_cursor).to eq(videos.last.id.to_s)
    expect(second_page.videos.map(&:id)).to eq([videos.second.id])
    expect(second_page.has_more).to eq(true)
  end

  it "rejects invalid cursor and limit inputs" do
    collection = create_collection(user: owner)

    expect do
      described_class.fetch(user: owner, collection_id: collection.id, cursor: "bad")
    end.to raise_error(VideoHub::CollectionCatalogQuery::CatalogError) { |error|
      expect(error.code).to eq(:invalid_cursor)
    }

    expect do
      described_class.fetch(user: owner, collection_id: collection.id, limit: 21)
    end.to raise_error(VideoHub::CollectionCatalogQuery::CatalogError) { |error|
      expect(error.code).to eq(:invalid_limit)
    }
  end

  it "keeps foreign collection targets fail-closed" do
    collection = create_collection(user: Fabricate(:user))

    expect do
      described_class.fetch(user: owner, collection_id: collection.id)
    end.to raise_error(Discourse::NotFound)
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
      external_id: "collection-catalog-service-#{@video_sequence}",
      canonical_url: "https://example.com/collection-catalog-service-#{@video_sequence}",
      kind: "landscape",
      title: "Catalog service #{@video_sequence}",
      author_name: "Catalog author",
      status: "published",
      published_at: Time.zone.now,
    )
  end
end
