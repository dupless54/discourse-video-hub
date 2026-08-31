# frozen_string_literal: true

describe VideoHub::CollectionQuery do
  let(:owner) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }

  before do
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_tiktok_enabled = true
    SiteSetting.video_hub_instagram_enabled = false
  end

  it "returns a visible collection and visible videos in deterministic collection order" do
    collection = create_collection(visible: true)
    first = create_video
    second = create_video
    place_video(collection, first, position: 1)
    place_video(collection, second, position: 0)

    result = described_class.fetch(user: nil, id: collection.id)

    expect(result.collection).to eq(collection)
    expect(result.owner).to eq(owner)
    expect(result.items.map(&:video)).to eq([second, first])
    expect(result.items.map { |item| item.collection_item.position }).to eq([0, 1])
  end

  it "filters disabled, unavailable, deleted, and hidden backing video records" do
    collection = create_collection(visible: true)
    visible = create_video
    disabled = create_video(provider: "instagram")
    unavailable = create_video(status: "unavailable")
    deleted_topic = create_video
    hidden_post = create_video

    deleted_topic.topic.update_column(:deleted_at, Time.zone.now)
    hidden_post.post.update_column(:hidden, true)

    [
      visible,
      disabled,
      unavailable,
      deleted_topic,
      hidden_post,
    ].each_with_index { |video, position| place_video(collection, video, position: position) }

    result = described_class.fetch(user: nil, id: collection.id)

    expect(result.items.map(&:video)).to eq([visible])
  end

  it "applies final Guardian profile and Topic/Post visibility before exposing collection data" do
    collection = create_collection(visible: true)
    visible = create_video
    hidden_by_guardian = create_video
    place_video(collection, visible, position: 0)
    place_video(collection, hidden_by_guardian, position: 1)

    guardian = mock
    guardian.stubs(:allowed_category_ids).returns([category.id])
    guardian.stubs(:can_see_profile?).with(owner).returns(true)
    guardian.stubs(:can_see?).returns(true)
    guardian.stubs(:can_see?).with(hidden_by_guardian.topic).returns(false)
    Guardian.expects(:new).with(nil).returns(guardian)

    result = described_class.fetch(user: nil, id: collection.id)

    expect(result.items.map(&:video)).to eq([visible])
  end

  it "keeps private and Guardian-hidden collections indistinguishable from missing records" do
    private_collection = create_collection(visible: false)

    expect { described_class.fetch(user: nil, id: private_collection.id) }.to raise_error(
      Discourse::NotFound,
    )

    public_collection = create_collection(visible: true, position: 1)
    guardian = mock
    guardian.expects(:can_see_profile?).with(owner).returns(false)
    Guardian.expects(:new).with(nil).returns(guardian)

    expect { described_class.fetch(user: nil, id: public_collection.id) }.to raise_error(
      Discourse::NotFound,
    )
  end

  it "rejects malformed or out-of-range collection identifiers" do
    expect { described_class.fetch(user: nil, id: "not-an-id") }.to raise_error(Discourse::NotFound)
    expect { described_class.fetch(user: nil, id: "0") }.to raise_error(Discourse::NotFound)
    expect do
      described_class.fetch(user: nil, id: VideoHub::WatchQuery::MAX_RECORD_ID + 1)
    end.to raise_error(Discourse::NotFound)
  end

  def create_collection(visible:, position: 0)
    VideoHub::VideoCollection.create!(
      user: owner,
      collection_type: "playlist",
      title: "Public collection #{position}",
      position: position,
      visible: visible,
    )
  end

  def place_video(collection, video, position:)
    VideoHub::VideoCollectionItem.create!(
      video_collection: collection,
      video: video,
      position: position,
    )
  end

  def create_video(provider: "youtube", status: "published")
    @video_sequence = @video_sequence.to_i + 1
    author = Fabricate(:user)
    topic = Fabricate(:topic, user: author, category: category)
    post = Fabricate(:post, topic: topic, user: author)

    VideoHub::Video.create!(
      user: author,
      topic: topic,
      post: post,
      provider: provider,
      external_id: "collection-query-#{@video_sequence}",
      canonical_url: "https://example.com/collection-query-#{@video_sequence}",
      kind: "landscape",
      title: "Collection query #{@video_sequence}",
      author_name: "Collection author",
      status: status,
      published_at: status == "published" ? Time.zone.now : nil,
    )
  end
end
