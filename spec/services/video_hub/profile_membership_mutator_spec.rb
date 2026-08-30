# frozen_string_literal: true

describe VideoHub::ProfileMembershipMutator do
  let(:profile_user) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }

  before do
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_tiktok_enabled = true
    SiteSetting.video_hub_instagram_enabled = false
  end

  it "bootstraps the matching profile section and appends a visible unpinned item" do
    video = create_video(kind: "shorts")

    result =
      described_class.add(user: profile_user, username: profile_user.username, video_id: video.id)

    expect(result.created).to eq(true)
    expect(result.profile_user).to eq(profile_user)
    expect(result.profile_section).to have_attributes(
      user_id: profile_user.id,
      section_type: "shorts",
      title: nil,
      position: 0,
      visible: true,
    )
    expect(result.profile_item).to have_attributes(
      profile_section_id: result.profile_section.id,
      video_id: video.id,
      position: 0,
      pinned: false,
      visible: true,
    )
  end

  it "reuses the matching section and keeps section and item positions contiguous" do
    shorts = create_section("shorts", 0)
    first_short = create_item(shorts, create_video(kind: "shorts"), 0)
    landscape_video = create_video(kind: "landscape")
    second_short = create_video(kind: "shorts")

    short_result =
      described_class.add(
        user: profile_user,
        username: profile_user.username,
        video_id: second_short.id,
      )
    landscape_result =
      described_class.add(
        user: profile_user,
        username: profile_user.username,
        video_id: landscape_video.id,
      )

    expect(short_result.profile_section).to eq(shorts)
    expect(shorts.items.order(:position).pluck(:id, :position)).to eq(
      [[first_short.id, 0], [short_result.profile_item.id, 1]],
    )
    expect(landscape_result.profile_section).to have_attributes(
      section_type: "landscape",
      position: 1,
      visible: true,
    )
    expect(
      VideoHub::ProfileSection.where(user_id: profile_user.id).order(:position).pluck(:position),
    ).to eq([0, 1])
  end

  it "treats an identical add retry as idempotent without resetting presentation state" do
    video = create_video(kind: "shorts")
    first =
      described_class.add(user: profile_user, username: profile_user.username, video_id: video.id)
    first.profile_item.update!(pinned: true, visible: false)

    retry_result =
      described_class.add(user: profile_user, username: profile_user.username, video_id: video.id)

    expect(retry_result.created).to eq(false)
    expect(retry_result.profile_section).to eq(first.profile_section)
    expect(retry_result.profile_item).to eq(first.profile_item)
    expect(retry_result.profile_item.reload).to have_attributes(pinned: true, visible: false)
    expect(VideoHub::ProfileSection.where(user_id: profile_user.id).count).to eq(1)
    expect(VideoHub::ProfileItem.where(profile_section_id: first.profile_section.id).count).to eq(1)
  end

  it "allows staff to mutate another user's profile membership" do
    video = create_video(kind: "shorts")

    result =
      described_class.add(
        user: Fabricate(:admin),
        username: profile_user.username,
        video_id: video.id,
      )

    expect(result.created).to eq(true)
    expect(result.profile_user).to eq(profile_user)
    expect(result.profile_item.video_id).to eq(video.id)
  end

  it "fails closed for missing profiles and viewers who cannot edit the target profile" do
    video = create_video(kind: "shorts")

    expect do
      described_class.add(
        user: Fabricate(:user),
        username: profile_user.username,
        video_id: video.id,
      )
    end.to raise_error(Discourse::NotFound)

    expect do
      described_class.add(user: profile_user, username: "missing-profile-user", video_id: video.id)
    end.to raise_error(Discourse::NotFound)

    expect(VideoHub::ProfileSection.where(user_id: profile_user.id)).to be_empty
  end

  it "fails closed for unpublished, disabled-provider, or hidden backing videos" do
    unavailable = create_video(kind: "shorts", status: "unavailable")
    disabled_provider = create_video(kind: "shorts", provider: "instagram")
    hidden_topic = create_video(kind: "shorts")
    hidden_topic.topic.update_column(:visible, false)

    [unavailable, disabled_provider, hidden_topic].each do |video|
      expect do
        described_class.add(user: profile_user, username: profile_user.username, video_id: video.id)
      end.to raise_error(Discourse::NotFound)
    end

    expect(VideoHub::ProfileSection.where(user_id: profile_user.id)).to be_empty
  end

  it "applies final Guardian visibility before adding a video" do
    video = create_video(kind: "shorts")
    guardian = mock
    guardian.expects(:can_edit_user?).with(profile_user).returns(true)
    guardian.expects(:can_see?).with(video.topic).returns(false)
    Guardian.expects(:new).with(profile_user).returns(guardian)

    expect do
      described_class.add(user: profile_user, username: profile_user.username, video_id: video.id)
    end.to raise_error(Discourse::NotFound)

    expect(VideoHub::ProfileSection.where(user_id: profile_user.id)).to be_empty
  end

  it "removes a placement, compacts remaining positions, and preserves the empty section" do
    section = create_section("shorts", 0)
    first = create_item(section, create_video(kind: "shorts"), 0)
    removed = create_item(section, create_video(kind: "shorts"), 1)
    last = create_item(section, create_video(kind: "shorts"), 2)
    removed.video.topic.update_column(:visible, false)

    expect(
      described_class.remove(
        user: profile_user,
        username: profile_user.username,
        video_id: removed.video_id,
      ),
    ).to eq(true)

    expect(section.reload).to be_persisted
    expect(section.items.order(:position).pluck(:id, :position)).to eq(
      [[first.id, 0], [last.id, 1]],
    )

    expect(
      described_class.remove(
        user: profile_user,
        username: profile_user.username,
        video_id: removed.video_id,
      ),
    ).to eq(false)
    expect(section.items.order(:position).pluck(:position)).to eq([0, 1])
  end

  it "does not remove another profile's placement when the target profile has no membership" do
    video = create_video(kind: "shorts")
    foreign_user = Fabricate(:user)
    foreign_section =
      VideoHub::ProfileSection.create!(
        user: foreign_user,
        section_type: "shorts",
        title: nil,
        position: 0,
        visible: true,
      )
    foreign_item =
      VideoHub::ProfileItem.create!(
        profile_section: foreign_section,
        video: video,
        position: 0,
        pinned: false,
        visible: true,
      )

    expect(
      described_class.remove(
        user: profile_user,
        username: profile_user.username,
        video_id: video.id,
      ),
    ).to eq(false)
    expect(foreign_item.reload).to be_persisted
  end

  def create_section(section_type, position)
    VideoHub::ProfileSection.create!(
      user: profile_user,
      section_type: section_type,
      title: nil,
      position: position,
      visible: true,
    )
  end

  def create_item(section, video, position)
    VideoHub::ProfileItem.create!(
      profile_section: section,
      video: video,
      position: position,
      pinned: false,
      visible: true,
    )
  end

  def create_video(kind:, provider: "youtube", status: "published")
    @video_sequence = @video_sequence.to_i + 1
    author = Fabricate(:user)
    topic = Fabricate(:topic, user: author, category: category)
    post = Fabricate(:post, topic: topic, user: author)

    VideoHub::Video.create!(
      user: author,
      topic: topic,
      post: post,
      provider: provider,
      external_id: "profile-membership-#{@video_sequence}",
      canonical_url: "https://example.com/profile-membership-#{@video_sequence}",
      kind: kind,
      title: "Profile membership #{@video_sequence}",
      author_name: "Profile author",
      status: status,
      published_at: status == "published" ? Time.zone.now : nil,
    )
  end
end

describe VideoHub::ProfileMembershipMutator, ".add" do
  self.use_transactional_tests = false

  after do
    VideoHub::ProfileItem.delete_all
    VideoHub::ProfileSection.delete_all
    VideoHub::Video.delete_all
  end

  it "serializes competing first-section adds without duplicate memberships or positions" do
    profile_user = Fabricate(:user)
    category = Fabricate(:category)
    SiteSetting.video_hub_youtube_enabled = true

    create_video =
      lambda do |kind, suffix|
        author = Fabricate(:user)
        topic = Fabricate(:topic, user: author, category: category)
        post = Fabricate(:post, topic: topic, user: author)

        VideoHub::Video.create!(
          user: author,
          topic: topic,
          post: post,
          provider: "youtube",
          external_id: "concurrent-membership-#{suffix}",
          canonical_url: "https://www.youtube.com/watch?v=concurrent-membership-#{suffix}",
          kind: kind,
          title: "Concurrent membership #{suffix}",
          author_name: "Profile author",
          status: "published",
          published_at: Time.zone.now,
        )
      end

    shorts = create_video.call("shorts", "shorts")
    landscape = create_video.call("landscape", "landscape")
    ready = Queue.new
    start = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!

    threads =
      [shorts.id, landscape.id].map do |video_id|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            editor = User.find(profile_user.id)
            ready << true
            start.pop
            described_class.add(user: editor, username: profile_user.username, video_id: video_id)
          end
        end
      end

    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:value)

    sections = VideoHub::ProfileSection.where(user_id: profile_user.id).order(:position).to_a
    expect(sections.map(&:position)).to eq([0, 1])
    expect(sections.map(&:section_type).sort).to eq(%w[landscape shorts])
    expect(VideoHub::ProfileItem.where(profile_section_id: sections.map(&:id)).count).to eq(2)
    expect(VideoHub::ProfileItem.group(:profile_section_id).count.values).to all(eq(1))
  end
end
