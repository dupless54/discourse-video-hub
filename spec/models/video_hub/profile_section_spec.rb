# frozen_string_literal: true

describe VideoHub::ProfileSection do
  let(:user) { Fabricate(:user) }

  def build_section(overrides = {})
    described_class.new(
      {
        user: user,
        section_type: "shorts",
        title: "Shorts",
        position: 0,
        visible: true,
      }.merge(overrides),
    )
  end

  it "accepts one bounded deterministic profile section" do
    section = build_section

    expect(section).to be_valid
  end

  it "restricts section type, title length, position and visibility" do
    section =
      build_section(
        section_type: "featured",
        title: "T" * (described_class::TITLE_MAX_LENGTH + 1),
        position: -1,
        visible: nil,
      )

    expect(section).not_to be_valid
    expect(section.errors[:section_type]).to be_present
    expect(section.errors[:title]).to be_present
    expect(section.errors[:position]).to be_present
    expect(section.errors[:visible]).to be_present
  end

  it "allows at most one section type and one position per owner" do
    described_class.create!(
      user: user,
      section_type: "shorts",
      position: 0,
      visible: true,
    )

    duplicate_type = build_section(position: 1)
    duplicate_position = build_section(section_type: "landscape")

    expect(duplicate_type).not_to be_valid
    expect(duplicate_type.errors[:section_type]).to be_present
    expect(duplicate_position).not_to be_valid
    expect(duplicate_position.errors[:position]).to be_present
  end

  it "keeps section type and position uniqueness scoped to the owner" do
    described_class.create!(
      user: user,
      section_type: "shorts",
      position: 0,
      visible: true,
    )
    other_user = Fabricate(:user)
    other_section =
      build_section(
        user: other_user,
        section_type: "shorts",
        position: 0,
      )

    expect(other_section).to be_valid
  end

  it "enforces owner-scoped section uniqueness at the database layer" do
    indexes = described_class.connection.indexes(:video_hub_profile_sections)

    type_index =
      indexes.find { |candidate| candidate.columns == %w[user_id section_type] }
    position_index =
      indexes.find { |candidate| candidate.columns == %w[user_id position] }

    expect(type_index).to be_present
    expect(type_index.unique).to eq(true)
    expect(position_index).to be_present
    expect(position_index.unique).to eq(true)
  end

  it "cascades profile presentation records when the owner is deleted" do
    foreign_key =
      described_class
        .connection
        .foreign_keys(:video_hub_profile_sections)
        .find { |candidate| candidate.to_table == "users" }

    expect(foreign_key).to be_present
    expect(foreign_key.options[:on_delete]).to eq(:cascade)
  end

  it "installs database constraints for section type and non-negative position" do
    constraint_names =
      described_class.connection.check_constraints(:video_hub_profile_sections).map(&:name)

    expect(constraint_names).to include(
      "video_hub_profile_sections_type",
      "video_hub_profile_sections_position",
    )
  end
end
