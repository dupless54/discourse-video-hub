# frozen_string_literal: true

describe VideoHub::SavedFeedQuery do
  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_tiktok_enabled = true
    SiteSetting.video_hub_instagram_enabled = true
  end

  let(:viewer) { Fabricate(:user) }
  let(:owner) { Fabricate(:user) }

  it "returns only the current viewer's visible saved videos in saved order" do
    older_video = create_video(owner: owner, external_id: "saved-order-older")
    newer_video = create_video(owner: owner, external_id: "saved-order-newer")
    other_video = create_video(owner: owner, external_id: "saved-order-other")
    older_time = Time.zone.parse("2026-08-31 01:00:00")
    newer_time = Time.zone.parse("2026-08-31 02:00:00")

    older_bookmark = save_video(viewer, older_video, at: older_time)
    newer_bookmark = save_video(viewer, newer_video, at: newer_time)
    save_video(Fabricate(:user), other_video, at: Time.zone.parse("2026-08-31 03:00:00"))

    result = described_class.fetch(user: viewer)

    expect(result.entries.map { |entry| entry.video.id }).to eq([newer_video.id, older_video.id])
    expect(result.entries.map(&:bookmark_id)).to eq([newer_bookmark.id, older_bookmark.id])
    expect(result.has_more).to eq(false)
    expect(result.next_cursor).to be_nil
  end

  it "paginates deterministically with the signed saved cursor" do
    first_video = create_video(owner: owner, external_id: "saved-page-first")
    second_video = create_video(owner: owner, external_id: "saved-page-second")
    third_video = create_video(owner: owner, external_id: "saved-page-third")

    save_video(viewer, first_video, at: Time.zone.parse("2026-08-31 03:00:00"))
    save_video(viewer, second_video, at: Time.zone.parse("2026-08-31 02:00:00"))
    third_bookmark = save_video(viewer, third_video, at: Time.zone.parse("2026-08-31 01:00:00"))

    first_page = described_class.fetch(user: viewer, limit: 2)
    second_page = described_class.fetch(user: viewer, cursor: first_page.next_cursor, limit: 2)

    expect(first_page.entries.map { |entry| entry.video.id }).to eq(
      [first_video.id, second_video.id],
    )
    expect(first_page.has_more).to eq(true)
    expect(first_page.next_cursor).to be_present
    expect(second_page.entries.map { |entry| entry.video.id }).to eq([third_video.id])
    expect(second_page.entries.first.bookmark_id).to eq(third_bookmark.id)
    expect(second_page.has_more).to eq(false)
    expect(second_page.next_cursor).to be_nil
  end

  it "filters disabled providers and videos hidden from the viewer" do
    visible_video = create_video(owner: owner, external_id: "saved-visible")
    disabled_video =
      create_video(owner: owner, provider: "tiktok", external_id: "saved-disabled-provider")
    private_category = Fabricate(:private_category, group: Fabricate(:group))
    private_video =
      create_video(owner: owner, category: private_category, external_id: "saved-private")

    visible_bookmark = save_video(viewer, visible_video, at: Time.zone.parse("2026-08-31 01:00:00"))
    save_video(viewer, disabled_video, at: Time.zone.parse("2026-08-31 02:00:00"))
    Bookmark.create!(user: viewer, bookmarkable: private_video.post).update_columns(
      updated_at: Time.zone.parse("2026-08-31 03:00:00"),
    )
    SiteSetting.video_hub_tiktok_enabled = false

    result = described_class.fetch(user: viewer)

    expect(result.entries.map { |entry| entry.video.id }).to eq([visible_video.id])
    expect(result.entries.first.bookmark_id).to eq(visible_bookmark.id)
  end

  it "ignores non-post bookmarks" do
    video = create_video(owner: owner, external_id: "saved-topic-bookmark")
    Bookmark.create!(user: viewer, bookmarkable: video.topic)

    result = described_class.fetch(user: viewer)

    expect(result.entries).to be_empty
  end

  it "rejects unauthenticated, malformed cursor, and invalid limit inputs" do
    expect { described_class.fetch(user: nil) }.to raise_error(
      VideoHub::SavedFeedQuery::FeedError,
    ) { |error| expect(error.code).to eq(:login_required) }

    expect { described_class.fetch(user: viewer, cursor: "bad cursor") }.to raise_error(
      VideoHub::SavedFeedQuery::FeedError,
    ) { |error| expect(error.code).to eq(:invalid_cursor) }

    expect { described_class.fetch(user: viewer, limit: 0) }.to raise_error(
      VideoHub::SavedFeedQuery::FeedError,
    ) { |error| expect(error.code).to eq(:invalid_limit) }
  end

  def save_video(user, video, at:)
    result = VideoHub::SavedVideo.save(user: user, video_id: video.id)
    bookmark = Bookmark.find(result.bookmark_id)
    bookmark.update_columns(updated_at: at)
    bookmark
  end

  def create_video(owner:, external_id:, provider: "youtube", category: nil)
    category ||= Fabricate(:category)
    topic = Fabricate(:topic, user: owner, category: category)
    post = Fabricate(:post, topic: topic, user: owner)

    VideoHub::Video.create!(
      user: owner,
      topic: topic,
      post: post,
      provider: provider,
      external_id: external_id,
      canonical_url: "https://example.com/#{external_id}",
      kind: "landscape",
      title: external_id,
      status: "published",
      published_at: Time.zone.now,
    )
  end
end
