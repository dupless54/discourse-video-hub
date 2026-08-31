# frozen_string_literal: true

describe VideoHub::VideoCollectionItem do
  let(:owner) { Fabricate(:user) }

  def create_video(user: Fabricate(:user), external_id: SecureRandom.hex(6))
    VideoHub::Video.create!(
      user: user,
      provider: "youtube",
      external_id: external_id,
      canonical_url: "https://www.youtube.com/watch?v=#{external_id}",
      kind: "landscape",
      status: "pending",
    )
  end

  def create_collection(user: owner, collection_type: "playlist", position: 0)
    VideoHub::VideoCollection.create!(
      user: user,
      collection_type: collection_type,
      title: "Collection #{SecureRandom.hex(3)}",
      position: position,
      visible: false,
    )
  end

  it "allows a playlist to contain a canonical video from another creator" do
    item =
      described_class.new(
        video_collection: create_collection(collection_type: "playlist"),
        video: create_video,
        position: 0,
      )

    expect(item).to be_valid
  end

  it "allows a series to contain the owner's canonical video" do
    item =
      described_class.new(
        video_collection: create_collection(collection_type: "series"),
        video: create_video(user: owner),
        position: 0,
      )

    expect(item).to be_valid
  end

  it "rejects another creator's video from a series" do
    item =
      described_class.new(
        video_collection: create_collection(collection_type: "series"),
        video: create_video(user: Fabricate(:user)),
        position: 0,
      )

    expect(item).not_to be_valid
    expect(item.errors[:video_id]).to be_present
  end

  it "requires unique video placement and position inside one collection" do
    collection = create_collection
    first_video = create_video
    second_video = create_video

    described_class.create!(video_collection: collection, video: first_video, position: 0)

    duplicate_video =
      described_class.new(video_collection: collection, video: first_video, position: 1)
    duplicate_position =
      described_class.new(video_collection: collection, video: second_video, position: 0)

    expect(duplicate_video).not_to be_valid
    expect(duplicate_video.errors[:video_id]).to be_present
    expect(duplicate_position).not_to be_valid
    expect(duplicate_position.errors[:position]).to be_present
  end

  it "allows the same canonical video in another collection" do
    video = create_video
    first_collection = create_collection(position: 0)
    second_collection = create_collection(position: 1)

    described_class.create!(video_collection: first_collection, video: video, position: 0)
    second_item =
      described_class.new(video_collection: second_collection, video: video, position: 0)

    expect(second_item).to be_valid
  end

  it "rejects negative positions" do
    item =
      described_class.new(
        video_collection: create_collection,
        video: create_video,
        position: -1,
      )

    expect(item).not_to be_valid
    expect(item.errors[:position]).to be_present
  end

  it "enforces placement uniqueness at the database layer" do
    indexes = described_class.connection.indexes(:video_hub_video_collection_items)
    video_index =
      indexes.find { |candidate| candidate.name == "idx_video_hub_collection_items_collection_video" }
    position_index =
      indexes.find { |candidate| candidate.name == "idx_video_hub_collection_items_collection_position" }

    expect(video_index).to be_present
    expect(video_index.unique).to eq(true)
    expect(video_index.columns).to eq(%w[video_collection_id video_id])
    expect(position_index).to be_present
    expect(position_index.unique).to eq(true)
    expect(position_index.columns).to eq(%w[video_collection_id position])
  end

  it "cascades items when their collection or canonical video is deleted" do
    foreign_keys = described_class.connection.foreign_keys(:video_hub_video_collection_items)
    collection_fk =
      foreign_keys.find { |candidate| candidate.to_table == "video_hub_video_collections" }
    video_fk = foreign_keys.find { |candidate| candidate.to_table == "video_hub_videos" }

    expect(collection_fk).to be_present
    expect(collection_fk.options[:on_delete]).to eq(:cascade)
    expect(video_fk).to be_present
    expect(video_fk.options[:on_delete]).to eq(:cascade)
  end

  it "installs a database constraint for non-negative item positions" do
    constraint_names =
      described_class.connection.check_constraints(:video_hub_video_collection_items).map(&:name)

    expect(constraint_names).to include("video_hub_collection_items_position")
  end
end
