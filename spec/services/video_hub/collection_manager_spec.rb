# frozen_string_literal: true

describe VideoHub::CollectionManager do
  let(:owner) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }

  before do
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_instagram_enabled = false
  end

  it "creates private owner-scoped collections in deterministic positions and lists only the owner" do
    first =
      described_class.create(
        user: owner,
        collection_type: "playlist",
        title: "First",
        description: "First collection",
      )
    second =
      described_class.create(
        user: owner,
        collection_type: "series",
        title: "Second",
        description: nil,
      )
    foreign = create_collection(user: Fabricate(:user), title: "Foreign", position: 0)

    expect(first.collection).to have_attributes(position: 0, visible: false)
    expect(second.collection).to have_attributes(position: 1, visible: false)
    expect(described_class.list(user: owner).map { |entry| entry.collection.id }).to eq(
      [first.collection.id, second.collection.id],
    )
    expect(described_class.list(user: owner).map { |entry| entry.collection.id }).not_to include(
      foreign.id,
    )
  end

  it "updates mutable metadata without allowing collection type changes" do
    collection =
      create_collection(user: owner, collection_type: "playlist", title: "Before", position: 0)

    result =
      described_class.update(
        user: owner,
        collection_id: collection.id,
        attributes: {
          title: "After",
          description: "Updated",
          visible: true,
          collection_type: "series",
        },
      )

    expect(result.collection.reload).to have_attributes(
      collection_type: "playlist",
      title: "After",
      description: "Updated",
      visible: true,
    )
  end

  it "fails closed when another user targets an owned collection" do
    collection = create_collection(user: owner, title: "Private", position: 0)
    other_user = Fabricate(:user)

    expect do
      described_class.update(
        user: other_user,
        collection_id: collection.id,
        attributes: {
          title: "Unauthorized",
        },
      )
    end.to raise_error(Discourse::NotFound)

    expect do
      described_class.destroy(user: other_user, collection_id: collection.id)
    end.to raise_error(Discourse::NotFound)

    expect(collection.reload.title).to eq("Private")
  end

  it "allows playlists to add a visible canonical video from another creator idempotently" do
    collection = create_collection(user: owner, collection_type: "playlist", position: 0)
    video = create_video(user: Fabricate(:user))

    first = described_class.add_video(user: owner, collection_id: collection.id, video_id: video.id)
    retry_result =
      described_class.add_video(user: owner, collection_id: collection.id, video_id: video.id)

    expect(first.created).to eq(true)
    expect(first.item).to have_attributes(video_id: video.id, position: 0)
    expect(retry_result.created).to eq(false)
    expect(retry_result.item.id).to eq(first.item.id)
    expect(collection.items.count).to eq(1)
  end

  it "allows series to add only the owner's own visible canonical videos" do
    collection = create_collection(user: owner, collection_type: "series", position: 0)
    own_video = create_video(user: owner)
    foreign_video = create_video(user: Fabricate(:user))

    result =
      described_class.add_video(user: owner, collection_id: collection.id, video_id: own_video.id)

    expect(result.item.video_id).to eq(own_video.id)

    expect do
      described_class.add_video(
        user: owner,
        collection_id: collection.id,
        video_id: foreign_video.id,
      )
    end.to raise_error(VideoHub::CollectionManager::CollectionError) { |error|
      expect(error.code).to eq(:series_video_not_owned)
    }
  end

  it "fails closed before adding a structurally hidden or disabled-provider video" do
    collection = create_collection(user: owner, position: 0)
    hidden_video = create_video(user: Fabricate(:user))
    hidden_video.topic.update_column(:deleted_at, Time.zone.now)
    disabled_video = create_video(user: Fabricate(:user), provider: "instagram")

    [hidden_video, disabled_video].each do |video|
      expect do
        described_class.add_video(user: owner, collection_id: collection.id, video_id: video.id)
      end.to raise_error(Discourse::NotFound)
    end

    expect(collection.items).to be_empty
  end

  it "removes membership idempotently and compacts remaining item positions" do
    collection = create_collection(user: owner, position: 0)
    first_video = create_video(user: Fabricate(:user))
    removed_video = create_video(user: Fabricate(:user))
    last_video = create_video(user: Fabricate(:user))

    first =
      described_class.add_video(user: owner, collection_id: collection.id, video_id: first_video.id)
    removed =
      described_class.add_video(
        user: owner,
        collection_id: collection.id,
        video_id: removed_video.id,
      )
    last =
      described_class.add_video(user: owner, collection_id: collection.id, video_id: last_video.id)

    expect(
      described_class.remove_video(
        user: owner,
        collection_id: collection.id,
        video_id: removed_video.id,
      ),
    ).to eq(true)
    expect(collection.items.order(:position).pluck(:id, :position)).to eq(
      [[first.item.id, 0], [last.item.id, 1]],
    )

    expect(
      described_class.remove_video(
        user: owner,
        collection_id: collection.id,
        video_id: removed_video.id,
      ),
    ).to eq(false)
    expect { removed.item.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "destroys an owned collection and compacts remaining collection positions" do
    first = create_collection(user: owner, title: "First", position: 0)
    removed = create_collection(user: owner, title: "Removed", position: 1)
    last = create_collection(user: owner, title: "Last", position: 2)

    expect(described_class.destroy(user: owner, collection_id: removed.id)).to eq(true)
    expect(
      VideoHub::VideoCollection.where(user_id: owner.id).order(:position).pluck(:id, :position),
    ).to eq([[first.id, 0], [last.id, 1]])
    expect { removed.reload }.to raise_error(ActiveRecord::RecordNotFound)
  end

  def create_collection(user:, collection_type: "playlist", title: "Collection", position:)
    VideoHub::VideoCollection.create!(
      user: user,
      collection_type: collection_type,
      title: title,
      position: position,
      visible: false,
    )
  end

  def create_video(user:, provider: "youtube")
    @video_sequence = @video_sequence.to_i + 1
    topic = Fabricate(:topic, user: user, category: category)
    post = Fabricate(:post, topic: topic, user: user)

    VideoHub::Video.create!(
      user: user,
      topic: topic,
      post: post,
      provider: provider,
      external_id: "collection-manager-#{@video_sequence}",
      canonical_url: "https://example.com/collection-manager-#{@video_sequence}",
      kind: "landscape",
      title: "Collection video #{@video_sequence}",
      author_name: "Collection author",
      status: "published",
      published_at: Time.zone.now,
    )
  end
end
