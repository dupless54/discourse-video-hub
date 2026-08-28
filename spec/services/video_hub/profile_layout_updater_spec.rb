# frozen_string_literal: true

describe VideoHub::ProfileLayoutUpdater do
  let(:profile_user) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }

  it "atomically reorders existing sections and items while updating presentation fields" do
    shorts = create_section("shorts", 0, "Shorts")
    landscape = create_section("landscape", 1, "Videos")
    first_short = create_item(shorts, create_video("shorts"), 0)
    second_short = create_item(shorts, create_video("shorts"), 1)
    landscape_item = create_item(landscape, create_video("landscape"), 0)

    result =
      described_class.update(
        user: profile_user,
        username: profile_user.username,
        sections: [
          section_input(
            landscape,
            position: 0,
            title: "Featured",
            visible: false,
            items: [item_input(landscape_item, position: 0, pinned: true, visible: false)],
          ),
          section_input(
            shorts,
            position: 1,
            title: nil,
            visible: true,
            items: [
              item_input(second_short, position: 0, pinned: true, visible: true),
              item_input(first_short, position: 1, pinned: false, visible: false),
            ],
          ),
        ],
      )

    expect(result.sections.map(&:profile_section)).to eq([landscape, shorts])
    expect(result.sections.last.items).to eq([second_short, first_short])
    expect(landscape.reload).to have_attributes(position: 0, title: "Featured", visible: false)
    expect(shorts.reload).to have_attributes(position: 1, title: nil, visible: true)
    expect(second_short.reload).to have_attributes(position: 0, pinned: true, visible: true)
    expect(first_short.reload).to have_attributes(position: 1, pinned: false, visible: false)
    expect(landscape_item.reload).to have_attributes(position: 0, pinned: true, visible: false)
  end

  it "allows staff to update another user's existing layout" do
    section = create_section("shorts", 0, "Shorts")
    item = create_item(section, create_video("shorts"), 0)

    described_class.update(
      user: Fabricate(:admin),
      username: profile_user.username,
      sections: [
        section_input(
          section,
          position: 0,
          title: "Staff curated",
          visible: true,
          items: [item_input(item, position: 0, pinned: true, visible: true)],
        ),
      ],
    )

    expect(section.reload.title).to eq("Staff curated")
    expect(item.reload.pinned).to eq(true)
  end

  it "fails closed for missing profiles and viewers who cannot edit the target user" do
    section = create_section("shorts", 0, "Shorts")
    item = create_item(section, create_video("shorts"), 0)
    payload = [
      section_input(
        section,
        position: 0,
        title: "Changed",
        visible: false,
        items: [item_input(item, position: 0, pinned: true, visible: false)],
      ),
    ]

    expect do
      described_class.update(
        user: Fabricate(:user),
        username: profile_user.username,
        sections: payload,
      )
    end.to raise_error(Discourse::NotFound)

    expect do
      described_class.update(user: profile_user, username: "missing-layout-user", sections: payload)
    end.to raise_error(Discourse::NotFound)

    expect(section.reload).to have_attributes(position: 0, title: "Shorts", visible: true)
    expect(item.reload).to have_attributes(position: 0, pinned: false, visible: true)
  end

  it "rejects non-member ids and non-contiguous positions without changing layout state" do
    shorts = create_section("shorts", 0, "Shorts")
    landscape = create_section("landscape", 1, "Videos")
    shorts_item = create_item(shorts, create_video("shorts"), 0)
    landscape_item = create_item(landscape, create_video("landscape"), 0)
    foreign_section =
      VideoHub::ProfileSection.create!(
        user: Fabricate(:user),
        section_type: "shorts",
        title: "Foreign",
        position: 0,
        visible: true,
      )

    invalid_membership = [
      section_input(foreign_section, position: 0, title: "Foreign", visible: true, items: []),
      section_input(
        landscape,
        position: 1,
        title: "Videos",
        visible: true,
        items: [item_input(landscape_item, position: 0, pinned: false, visible: true)],
      ),
    ]

    expect do
      described_class.update(
        user: profile_user,
        username: profile_user.username,
        sections: invalid_membership,
      )
    end.to raise_error(VideoHub::ProfileLayoutUpdater::LayoutError) do |error|
      expect(error.code).to eq(:invalid_layout)
    end

    invalid_positions = [
      section_input(
        shorts,
        position: 0,
        title: "Changed",
        visible: false,
        items: [item_input(shorts_item, position: 0, pinned: true, visible: false)],
      ),
      section_input(
        landscape,
        position: 0,
        title: "Also changed",
        visible: false,
        items: [item_input(landscape_item, position: 0, pinned: true, visible: false)],
      ),
    ]

    expect do
      described_class.update(
        user: profile_user,
        username: profile_user.username,
        sections: invalid_positions,
      )
    end.to raise_error(VideoHub::ProfileLayoutUpdater::LayoutError)

    expect(shorts.reload).to have_attributes(position: 0, title: "Shorts", visible: true)
    expect(landscape.reload).to have_attributes(position: 1, title: "Videos", visible: true)
    expect(shorts_item.reload).to have_attributes(position: 0, pinned: false, visible: true)
  end

  it "fails closed when an existing layout item points at backing content hidden from the editor" do
    section = create_section("shorts", 0, "Shorts")
    video = create_video("shorts")
    item = create_item(section, video, 0)
    video.topic.update_column(:visible, false)

    expect do
      described_class.update(
        user: profile_user,
        username: profile_user.username,
        sections: [
          section_input(
            section,
            position: 0,
            title: "Changed",
            visible: false,
            items: [item_input(item, position: 0, pinned: true, visible: false)],
          ),
        ],
      )
    end.to raise_error(Discourse::NotFound)

    expect(section.reload).to have_attributes(title: "Shorts", visible: true)
    expect(item.reload).to have_attributes(pinned: false, visible: true)
  end

  it "accepts an identical retry without creating duplicate state" do
    section = create_section("shorts", 0, "Shorts")
    item = create_item(section, create_video("shorts"), 0)
    payload = [
      section_input(
        section,
        position: 0,
        title: "Pinned clips",
        visible: true,
        items: [item_input(item, position: 0, pinned: true, visible: true)],
      ),
    ]

    2.times do
      described_class.update(user: profile_user, username: profile_user.username, sections: payload)
    end

    expect(VideoHub::ProfileSection.where(user_id: profile_user.id).count).to eq(1)
    expect(VideoHub::ProfileItem.where(profile_section_id: section.id).count).to eq(1)
    expect(section.reload.title).to eq("Pinned clips")
    expect(item.reload.pinned).to eq(true)
  end

  def create_section(section_type, position, title)
    VideoHub::ProfileSection.create!(
      user: profile_user,
      section_type: section_type,
      title: title,
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

  def create_video(kind)
    @video_sequence = @video_sequence.to_i + 1
    author = Fabricate(:user)
    topic = Fabricate(:topic, user: author, category: category)
    post = Fabricate(:post, topic: topic, user: author)

    VideoHub::Video.create!(
      user: author,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: "profile-layout-#{@video_sequence}",
      canonical_url: "https://www.youtube.com/watch?v=profile-layout-#{@video_sequence}",
      kind: kind,
      title: "Profile layout #{@video_sequence}",
      author_name: "Profile author",
      status: "published",
      published_at: Time.zone.now,
    )
  end

  def section_input(section, position:, title:, visible:, items:)
    { id: section.id, position: position, title: title, visible: visible, items: items }
  end

  def item_input(item, position:, pinned:, visible:)
    { id: item.id, position: position, pinned: pinned, visible: visible }
  end
end

describe VideoHub::ProfileLayoutUpdater, "concurrent reorders" do
  self.use_transactional_tests = false

  it "serializes competing reorder snapshots without leaving a partial layout" do
    profile_user = Fabricate(:user)
    category = Fabricate(:category)
    video_sequence = 0
    create_video =
      lambda do |kind|
        video_sequence += 1
        author = Fabricate(:user)
        topic = Fabricate(:topic, user: author, category: category)
        post = Fabricate(:post, topic: topic, user: author)

        VideoHub::Video.create!(
          user: author,
          topic: topic,
          post: post,
          provider: "youtube",
          external_id: "concurrent-profile-layout-#{topic.id}-#{video_sequence}",
          canonical_url: "https://www.youtube.com/watch?v=concurrent-#{topic.id}-#{video_sequence}",
          kind: kind,
          title: "Concurrent profile layout #{video_sequence}",
          author_name: "Profile author",
          status: "published",
          published_at: Time.zone.now,
        )
      end

    shorts =
      VideoHub::ProfileSection.create!(
        user: profile_user,
        section_type: "shorts",
        title: "Shorts",
        position: 0,
        visible: true,
      )
    landscape =
      VideoHub::ProfileSection.create!(
        user: profile_user,
        section_type: "landscape",
        title: "Videos",
        position: 1,
        visible: true,
      )
    first_short =
      VideoHub::ProfileItem.create!(
        profile_section: shorts,
        video: create_video.call("shorts"),
        position: 0,
        pinned: false,
        visible: true,
      )
    second_short =
      VideoHub::ProfileItem.create!(
        profile_section: shorts,
        video: create_video.call("shorts"),
        position: 1,
        pinned: false,
        visible: true,
      )
    landscape_item =
      VideoHub::ProfileItem.create!(
        profile_section: landscape,
        video: create_video.call("landscape"),
        position: 0,
        pinned: false,
        visible: true,
      )

    first_snapshot = [
      {
        id: landscape.id,
        position: 0,
        title: "First landscape",
        visible: false,
        items: [{ id: landscape_item.id, position: 0, pinned: true, visible: false }],
      },
      {
        id: shorts.id,
        position: 1,
        title: "First shorts",
        visible: true,
        items: [
          { id: second_short.id, position: 0, pinned: true, visible: true },
          { id: first_short.id, position: 1, pinned: false, visible: false },
        ],
      },
    ]
    second_snapshot = [
      {
        id: shorts.id,
        position: 0,
        title: "Second shorts",
        visible: false,
        items: [
          { id: first_short.id, position: 0, pinned: true, visible: false },
          { id: second_short.id, position: 1, pinned: false, visible: true },
        ],
      },
      {
        id: landscape.id,
        position: 1,
        title: "Second landscape",
        visible: true,
        items: [{ id: landscape_item.id, position: 0, pinned: false, visible: true }],
      },
    ]

    ready = Queue.new
    start = Queue.new
    threads =
      [first_snapshot, second_snapshot].map do |snapshot|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            editor = User.find(profile_user.id)
            ready << true
            start.pop
            described_class.update(
              user: editor,
              username: profile_user.username,
              sections: snapshot,
            )
          end
        end
      end

    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:value)

    payload_signature =
      lambda do |snapshot|
        snapshot.sort_by { |section| section[:position] }.map do |section|
          [
            section[:id],
            section[:title],
            section[:visible],
            section[:items]
              .sort_by { |item| item[:position] }
              .map { |item| [item[:id], item[:pinned], item[:visible]] },
          ]
        end
      end
    persisted_signature =
      VideoHub::ProfileSection.where(user_id: profile_user.id).order(:position).map do |section|
        [
          section.id,
          section.title,
          section.visible,
          section.items.order(:position).map { |item| [item.id, item.pinned, item.visible] },
        ]
      end

    expect(
      [payload_signature.call(first_snapshot), payload_signature.call(second_snapshot)],
    ).to include(persisted_signature)
    expect(VideoHub::ProfileSection.where(user_id: profile_user.id).order(:position).pluck(:position)).to eq(
      [0, 1],
    )
    expect(shorts.items.order(:position).pluck(:position)).to eq([0, 1])
  end
end
