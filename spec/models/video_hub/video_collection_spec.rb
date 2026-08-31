# frozen_string_literal: true

describe VideoHub::VideoCollection do
  let(:owner) { Fabricate(:user) }

  def build_collection(**overrides)
    described_class.new(
      {
        user: owner,
        collection_type: "playlist",
        title: "Watch later with friends",
        description: "A bounded collection description",
        position: 0,
        visible: false,
      }.merge(overrides),
    )
  end

  it "accepts playlist and series collections" do
    expect(build_collection(collection_type: "playlist")).to be_valid
    expect(build_collection(collection_type: "series")).to be_valid
  end

  it "requires a supported type, bounded title, and bounded description" do
    invalid_type = build_collection(collection_type: "unknown")
    blank_title = build_collection(title: "   ")
    long_title = build_collection(title: "x" * (described_class::TITLE_MAX_LENGTH + 1))
    long_description =
      build_collection(description: "x" * (described_class::DESCRIPTION_MAX_LENGTH + 1))

    expect(invalid_type).not_to be_valid
    expect(invalid_type.errors[:collection_type]).to be_present
    expect(blank_title).not_to be_valid
    expect(blank_title.errors[:title]).to be_present
    expect(long_title).not_to be_valid
    expect(long_title.errors[:title]).to be_present
    expect(long_description).not_to be_valid
    expect(long_description.errors[:description]).to be_present
  end

  it "requires a non-negative owner-scoped position and explicit visibility" do
    negative_position = build_collection(position: -1)
    missing_visibility = build_collection(visible: nil)

    expect(negative_position).not_to be_valid
    expect(negative_position.errors[:position]).to be_present
    expect(missing_visibility).not_to be_valid
    expect(missing_visibility.errors[:visible]).to be_present
  end

  it "keeps collection positions unique per owner" do
    described_class.create!(
      user: owner,
      collection_type: "playlist",
      title: "First",
      position: 0,
      visible: false,
    )

    duplicate_position = build_collection(title: "Second", position: 0)
    other_owner_collection =
      build_collection(user: Fabricate(:user), title: "Other owner", position: 0)

    expect(duplicate_position).not_to be_valid
    expect(duplicate_position.errors[:position]).to be_present
    expect(other_owner_collection).to be_valid
  end

  it "defaults new persisted collections to private visibility" do
    collection =
      described_class.create!(
        user: owner,
        collection_type: "playlist",
        title: "Private by default",
        position: 0,
      )

    expect(collection.visible).to eq(false)
  end

  it "enforces owner position uniqueness and lookup indexes at the database layer" do
    indexes = described_class.connection.indexes(:video_hub_video_collections)
    position_index =
      indexes.find { |candidate| candidate.name == "idx_video_hub_collections_owner_position" }
    type_index =
      indexes.find { |candidate| candidate.name == "idx_video_hub_collections_owner_type" }

    expect(position_index).to be_present
    expect(position_index.unique).to eq(true)
    expect(position_index.columns).to eq(%w[user_id position])
    expect(type_index).to be_present
    expect(type_index.columns).to eq(%w[user_id collection_type])
  end

  it "installs collection type and position database constraints" do
    constraint_names =
      described_class.connection.check_constraints(:video_hub_video_collections).map(&:name)

    expect(constraint_names).to include("video_hub_collections_type")
    expect(constraint_names).to include("video_hub_collections_position")
  end

  it "cascades collections when their owner is deleted" do
    foreign_keys = described_class.connection.foreign_keys(:video_hub_video_collections)
    owner_fk = foreign_keys.find { |candidate| candidate.to_table == "users" }

    expect(owner_fk).to be_present
    expect(owner_fk.options[:on_delete]).to eq(:cascade)
  end
end
