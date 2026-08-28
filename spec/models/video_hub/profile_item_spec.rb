# frozen_string_literal: true

describe VideoHub::ProfileItem do
  let(:owner) { Fabricate(:user) }

  def create_video(kind: "shorts", external_id: SecureRandom.hex(6))
    VideoHub::Video.create!(
      user: Fabricate(:user),
      provider: "youtube",
      external_id: external_id,
      canonical_url: "https://www.youtube.com/watch?v=#{external_id}",
      kind: kind,
      status: "pending",
    )
  end

  def create_section(user: owner, section_type: "shorts", position: 0)
    VideoHub::ProfileSection.create!(
      user: user,
      section_type: section_type,
      position: position,
      visible: true,
    )
  end

  it "accepts a video whose kind matches the section type" do
    item =
      described_class.new(
        profile_section: create_section,
        video: create_video,
        position: 0,
        pinned: false,
        visible: true,
      )

    expect(item).to be_valid
  end

  it "rejects placing a video into a section with a different kind" do
    item =
      described_class.new(
        profile_section: create_section(section_type: "shorts"),
        video: create_video(kind: "landscape"),
        position: 0,
        pinned: false,
        visible: true,
      )

    expect(item).not_to be_valid
    expect(item.errors[:video_id]).to be_present
  end

  it "requires unique video placement and position inside one section" do
    section = create_section
    first_video = create_video
    second_video = create_video

    described_class.create!(
      profile_section: section,
      video: first_video,
      position: 0,
      pinned: false,
      visible: true,
    )

    duplicate_video =
      described_class.new(
        profile_section: section,
        video: first_video,
        position: 1,
        pinned: false,
        visible: true,
      )
    duplicate_position =
      described_class.new(
        profile_section: section,
        video: second_video,
        position: 0,
        pinned: false,
        visible: true,
      )

    expect(duplicate_video).not_to be_valid
    expect(duplicate_video.errors[:video_id]).to be_present
    expect(duplicate_position).not_to be_valid
    expect(duplicate_position.errors[:position]).to be_present
  end

  it "allows the same canonical video in a matching section owned by another user" do
    video = create_video
    first_section = create_section
    other_owner = Fabricate(:user)
    second_section = create_section(user: other_owner)

    described_class.create!(
      profile_section: first_section,
      video: video,
      position: 0,
      pinned: false,
      visible: true,
    )
    second_item =
      described_class.new(
        profile_section: second_section,
        video: video,
        position: 0,
        pinned: true,
        visible: true,
      )

    expect(second_item).to be_valid
  end

  it "rejects negative positions and nullable placement controls" do
    item =
      described_class.new(
        profile_section: create_section,
        video: create_video,
        position: -1,
        pinned: nil,
        visible: nil,
      )

    expect(item).not_to be_valid
    expect(item.errors[:position]).to be_present
    expect(item.errors[:pinned]).to be_present
    expect(item.errors[:visible]).to be_present
  end

  it "enforces placement uniqueness at the database layer" do
    indexes = described_class.connection.indexes(:video_hub_profile_items)
    video_index = indexes.find { |candidate| candidate.columns == %w[profile_section_id video_id] }
    position_index =
      indexes.find { |candidate| candidate.columns == %w[profile_section_id position] }

    expect(video_index).to be_present
    expect(video_index.unique).to eq(true)
    expect(position_index).to be_present
    expect(position_index.unique).to eq(true)
  end

  it "cascades placements when their section or canonical video is deleted" do
    foreign_keys = described_class.connection.foreign_keys(:video_hub_profile_items)
    section_fk =
      foreign_keys.find { |candidate| candidate.to_table == "video_hub_profile_sections" }
    video_fk = foreign_keys.find { |candidate| candidate.to_table == "video_hub_videos" }

    expect(section_fk).to be_present
    expect(section_fk.options[:on_delete]).to eq(:cascade)
    expect(video_fk).to be_present
    expect(video_fk.options[:on_delete]).to eq(:cascade)
  end

  it "installs a database constraint for non-negative item positions" do
    constraint_names =
      described_class.connection.check_constraints(:video_hub_profile_items).map(&:name)

    expect(constraint_names).to include("video_hub_profile_items_position")
  end
end
