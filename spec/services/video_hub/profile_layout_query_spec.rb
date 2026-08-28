# frozen_string_literal: true

describe VideoHub::ProfileLayoutQuery do
  let(:profile_user) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }

  it "returns every existing section and item in deterministic layout order" do
    landscape = create_section("landscape", 1, visible: false)
    shorts = create_section("shorts", 0, visible: true)
    later_short = create_item(shorts, create_video("shorts"), 1, visible: false)
    first_short = create_item(shorts, create_video("shorts"), 0, visible: true)
    landscape_item = create_item(landscape, create_video("landscape"), 0, visible: false)

    result = described_class.fetch(user: profile_user, username: profile_user.username)

    expect(result.profile_user).to eq(profile_user)
    expect(result.sections.map(&:profile_section)).to eq([shorts, landscape])
    expect(result.sections.first.items.map(&:profile_item)).to eq([first_short, later_short])
    expect(result.sections.last.items.map(&:profile_item)).to eq([landscape_item])
    expect(result.sections.first.items.map(&:video)).to eq(
      [first_short.video, later_short.video],
    )
  end

  it "allows staff to read another user's complete layout" do
    section = create_section("shorts", 0, visible: false)
    item = create_item(section, create_video("shorts"), 0, visible: false)

    result =
      described_class.fetch(
        user: Fabricate(:admin),
        username: profile_user.username,
      )

    expect(result.sections.first.profile_section).to eq(section)
    expect(result.sections.first.items.first.profile_item).to eq(item)
  end

  it "fails closed for missing profiles and viewers who cannot edit the target user" do
    expect do
      described_class.fetch(user: Fabricate(:user), username: profile_user.username)
    end.to raise_error(Discourse::NotFound)

    expect do
      described_class.fetch(user: profile_user, username: "missing-layout-profile")
    end.to raise_error(Discourse::NotFound)

    expect do
      described_class.fetch(user: nil, username: profile_user.username)
    end.to raise_error(Discourse::NotFound)
  end

  it "fails closed when an existing item points at a structurally hidden topic" do
    section = create_section("shorts", 0, visible: true)
    video = create_video("shorts")
    create_item(section, video, 0, visible: true)
    video.topic.update_column(:visible, false)

    expect do
      described_class.fetch(user: profile_user, username: profile_user.username)
    end.to raise_error(Discourse::NotFound)
  end

  it "fails closed when Guardian cannot see backing content" do
    private_category = Fabricate(:private_category, group: Fabricate(:group))
    section = create_section("shorts", 0, visible: true)
    author = Fabricate(:user)
    topic = Fabricate(:topic, user: author, category: private_category)
    post = Fabricate(:post, topic: topic, user: author)
    video = create_video_record("shorts", author:, topic:, post:)
    create_item(section, video, 0, visible: true)

    expect do
      described_class.fetch(user: profile_user, username: profile_user.username)
    end.to raise_error(Discourse::NotFound)
  end

  def create_section(section_type, position, visible:)
    VideoHub::ProfileSection.create!(
      user: profile_user,
      section_type: section_type,
      title: section_type == "shorts" ? "Shorts" : "Videos",
      position: position,
      visible: visible,
    )
  end

  def create_item(section, video, position, visible:)
    VideoHub::ProfileItem.create!(
      profile_section: section,
      video: video,
      position: position,
      pinned: position.zero?,
      visible: visible,
    )
  end

  def create_video(kind)
    author = Fabricate(:user)
    topic = Fabricate(:topic, user: author, category: category)
    post = Fabricate(:post, topic: topic, user: author)

    create_video_record(kind, author:, topic:, post:)
  end

  def create_video_record(kind, author:, topic:, post:)
    @video_sequence = @video_sequence.to_i + 1

    VideoHub::Video.create!(
      user: author,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: "profile-layout-read-#{@video_sequence}",
      canonical_url: "https://www.youtube.com/watch?v=profile-layout-read-#{@video_sequence}",
      kind: kind,
      title: "Profile layout read #{@video_sequence}",
      thumbnail_url: "https://example.com/profile-layout-read.jpg",
      duration_seconds: 20,
      author_name: "Profile author",
      status: "published",
      published_at: Time.zone.now,
    )
  end
end
