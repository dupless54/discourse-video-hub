# frozen_string_literal: true

describe VideoHub::ProfileQuery do
  let(:profile_user) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }

  before do
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_tiktok_enabled = true
    SiteSetting.video_hub_instagram_enabled = false
  end

  it "returns visible sections and items in deterministic profile order" do
    landscape = create_section(section_type: "landscape", position: 1)
    shorts = create_section(section_type: "shorts", position: 0)
    landscape_video = create_video(kind: "landscape")
    shorts_second = create_video(kind: "shorts")
    shorts_first = create_video(kind: "shorts")

    place_video(landscape, landscape_video, position: 0)
    place_video(shorts, shorts_second, position: 1, pinned: true)
    place_video(shorts, shorts_first, position: 0)

    result = described_class.fetch(user: nil, username: profile_user.username)

    expect(result.profile_user).to eq(profile_user)
    expect(result.sections.map { |section| section.profile_section }).to eq([shorts, landscape])
    expect(result.sections.first.items.map(&:video)).to eq([shorts_first, shorts_second])
    expect(result.sections.first.items.last.profile_item.pinned).to eq(true)
  end

  it "fails closed for missing or Guardian-hidden profiles" do
    expect { described_class.fetch(user: nil, username: "missing-video-profile") }.to raise_error(
      Discourse::NotFound,
    )

    guardian = mock
    guardian.expects(:can_see_profile?).with(profile_user).returns(false)
    Guardian.expects(:new).with(nil).returns(guardian)

    expect { described_class.fetch(user: nil, username: profile_user.username) }.to raise_error(
      Discourse::NotFound,
    )
  end

  it "filters hidden presentation state and ineligible backing video records" do
    shorts = create_section(section_type: "shorts", position: 0)
    hidden_section = create_section(section_type: "landscape", position: 1, visible: false)

    visible = create_video(kind: "shorts")
    hidden_item = create_video(kind: "shorts")
    disabled_provider = create_video(kind: "shorts", provider: "instagram")
    unavailable = create_video(kind: "shorts", status: "unavailable")
    invisible_topic = create_video(kind: "shorts")
    hidden_post = create_video(kind: "shorts")
    hidden_section_video = create_video(kind: "landscape")

    invisible_topic.topic.update_column(:visible, false)
    hidden_post.post.update_column(:hidden, true)

    place_video(shorts, visible, position: 0)
    place_video(shorts, hidden_item, position: 1, visible: false)
    place_video(shorts, disabled_provider, position: 2)
    place_video(shorts, unavailable, position: 3)
    place_video(shorts, invisible_topic, position: 4)
    place_video(shorts, hidden_post, position: 5)
    place_video(hidden_section, hidden_section_video, position: 0)

    result = described_class.fetch(user: nil, username: profile_user.username)

    expect(result.sections.map(&:profile_section)).to eq([shorts])
    expect(result.sections.first.items.map(&:video)).to eq([visible])
  end

  it "filters deleted Topics and Posts before exposing profile items" do
    section = create_section(section_type: "shorts", position: 0)
    visible = create_video(kind: "shorts")
    deleted_topic = create_video(kind: "shorts")
    deleted_post = create_video(kind: "shorts")

    deleted_topic.topic.update_column(:deleted_at, Time.zone.now)
    deleted_post.post.update_column(:deleted_at, Time.zone.now)

    place_video(section, visible, position: 0)
    place_video(section, deleted_topic, position: 1)
    place_video(section, deleted_post, position: 2)

    result = described_class.fetch(user: nil, username: profile_user.username)

    expect(result.sections.first.items.map(&:video)).to eq([visible])
  end

  it "applies final Guardian visibility after database candidate filtering" do
    section = create_section(section_type: "shorts", position: 0)
    visible = create_video(kind: "shorts")
    hidden_by_guardian = create_video(kind: "shorts")
    place_video(section, visible, position: 0)
    place_video(section, hidden_by_guardian, position: 1)

    guardian = mock
    guardian.stubs(:allowed_category_ids).returns([category.id])
    guardian.stubs(:can_see_profile?).with(profile_user).returns(true)
    guardian.stubs(:can_see?).returns(true)
    guardian.stubs(:can_see?).with(hidden_by_guardian.topic).returns(false)
    Guardian.expects(:new).with(nil).returns(guardian)

    result = described_class.fetch(user: nil, username: profile_user.username)

    expect(result.sections.first.items.map(&:video)).to eq([visible])
  end

  def create_section(section_type:, position:, visible: true)
    VideoHub::ProfileSection.create!(
      user: profile_user,
      section_type: section_type,
      title: section_type.capitalize,
      position: position,
      visible: visible,
    )
  end

  def place_video(section, video, position:, pinned: false, visible: true)
    VideoHub::ProfileItem.create!(
      profile_section: section,
      video: video,
      position: position,
      pinned: pinned,
      visible: visible,
    )
  end

  def create_video(kind:, provider: "youtube", status: "published")
    @video_sequence = @video_sequence.to_i + 1
    external_id = "profile-video-#{@video_sequence}"
    author = Fabricate(:user)
    topic = Fabricate(:topic, user: author, category: category)
    post = Fabricate(:post, topic: topic, user: author)

    VideoHub::Video.create!(
      user: author,
      topic: topic,
      post: post,
      provider: provider,
      external_id: external_id,
      canonical_url: "https://example.com/#{external_id}",
      kind: kind,
      title: "Profile video #{@video_sequence}",
      thumbnail_url: nil,
      duration_seconds: nil,
      author_name: "Profile author",
      status: status,
      published_at: status == "published" ? Time.zone.now : nil,
    )
  end
end
