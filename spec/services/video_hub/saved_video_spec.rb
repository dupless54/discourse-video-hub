# frozen_string_literal: true

describe VideoHub::SavedVideo do
  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
  end

  let(:viewer) { Fabricate(:user) }
  let(:owner) { Fabricate(:user) }
  let(:video) { create_video(owner: owner) }

  it "returns an anonymous unsaved state without exposing bookmark data" do
    state = described_class.state(user: nil, video: video)

    expect(state.saved).to eq(false)
    expect(state.bookmark_id).to be_nil
  end

  it "returns only the requested viewer's core bookmark state" do
    other_viewer = Fabricate(:user)
    other_bookmark = described_class.save(user: other_viewer, video_id: video.id)

    viewer_state = described_class.state(user: viewer, video: video)
    other_state = described_class.state(user: other_viewer, video: video)

    expect(viewer_state.saved).to eq(false)
    expect(viewer_state.bookmark_id).to be_nil
    expect(other_state.saved).to eq(true)
    expect(other_state.bookmark_id).to eq(other_bookmark.bookmark_id)
  end

  it "saves the visible video's root post through the core bookmark model" do
    result = described_class.save(user: viewer, video_id: video.id)
    bookmark = Bookmark.find(result.bookmark_id)

    expect(result.saved).to eq(true)
    expect(bookmark.user_id).to eq(viewer.id)
    expect(bookmark.bookmarkable_type).to eq(Post.polymorphic_name)
    expect(bookmark.bookmarkable_id).to eq(video.post_id)
  end

  it "is idempotent when the same viewer saves the same video again" do
    first = described_class.save(user: viewer, video_id: video.id)
    second = described_class.save(user: viewer, video_id: video.id)

    expect(second.saved).to eq(true)
    expect(second.bookmark_id).to eq(first.bookmark_id)
    expect(
      Bookmark.where(
        user_id: viewer.id,
        bookmarkable_type: Post.polymorphic_name,
        bookmarkable_id: video.post_id,
      ).count,
    ).to eq(1)
  end

  it "removes only the current viewer's saved state and remains idempotent" do
    other_viewer = Fabricate(:user)
    viewer_bookmark = described_class.save(user: viewer, video_id: video.id)
    other_bookmark = described_class.save(user: other_viewer, video_id: video.id)

    first_unsave = described_class.unsave(user: viewer, video_id: video.id)
    second_unsave = described_class.unsave(user: viewer, video_id: video.id)

    expect(first_unsave.saved).to eq(false)
    expect(first_unsave.bookmark_id).to be_nil
    expect(second_unsave.saved).to eq(false)
    expect(Bookmark.exists?(viewer_bookmark.bookmark_id)).to eq(false)
    expect(Bookmark.exists?(other_bookmark.bookmark_id)).to eq(true)
  end

  it "preserves not-found semantics for an invisible backing topic" do
    group = Fabricate(:group)
    private_category = Fabricate(:private_category, group: group)
    private_video = create_video(owner: owner, category: private_category)

    expect { described_class.save(user: viewer, video_id: private_video.id) }.to raise_error(
      Discourse::NotFound,
    )
    expect { described_class.unsave(user: viewer, video_id: private_video.id) }.to raise_error(
      Discourse::NotFound,
    )
  end

  it "does not expose unavailable videos through saved state mutations" do
    unavailable = create_video(owner: owner, status: "unavailable")

    expect { described_class.save(user: viewer, video_id: unavailable.id) }.to raise_error(
      Discourse::NotFound,
    )
    expect { described_class.unsave(user: viewer, video_id: unavailable.id) }.to raise_error(
      Discourse::NotFound,
    )
  end

  def create_video(owner:, category: nil, status: "published")
    @video_sequence = @video_sequence.to_i + 1
    topic = Fabricate(:topic, user: owner, category: category)
    post = Fabricate(:post, topic: topic, user: owner)

    VideoHub::Video.create!(
      user: owner,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: "saved-video-#{@video_sequence}",
      canonical_url: "https://www.youtube.com/watch?v=saved-video-#{@video_sequence}",
      kind: "landscape",
      title: "Saved video #{@video_sequence}",
      status: status,
      published_at: status == "published" ? Time.zone.now : nil,
    )
  end
end
