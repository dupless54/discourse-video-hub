# frozen_string_literal: true

describe "Video Hub saved feed" do
  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
  end

  let(:viewer) { Fabricate(:user) }
  let(:owner) { Fabricate(:user) }
  let(:video) { create_video(owner: owner) }

  it "requires login before querying saved videos" do
    VideoHub::SavedFeedQuery.expects(:fetch).never

    get "/videos/saved/feed.json"

    expect(response.status).to eq(403)
  end

  it "passes the authenticated viewer and bounded pagination inputs to the saved query" do
    sign_in(viewer)
    entry =
      VideoHub::SavedFeedQuery::Entry.new(
        video: video,
        bookmark_id: 77,
        saved_at: Time.zone.parse("2026-08-31 02:00:00"),
      ).freeze
    VideoHub::SavedFeedQuery
      .expects(:fetch)
      .with(user: viewer, cursor: "cursor-token", limit: "2")
      .returns(
        VideoHub::SavedFeedQuery::Result.new(
          entries: [entry],
          has_more: true,
          next_cursor: "next-token",
        ),
      )

    get "/videos/saved/feed.json", params: { cursor: "cursor-token", limit: 2 }

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq(
      {
        "videos" => [video_payload(video).merge("saved" => true, "bookmark_id" => 77)],
        "pagination" => {
          "has_more" => true,
          "next_cursor" => "next-token",
        },
      },
    )
  end

  it "maps malformed saved-feed inputs to a safe bad request" do
    sign_in(viewer)
    VideoHub::SavedFeedQuery.expects(:fetch).raises(
      VideoHub::SavedFeedQuery::FeedError.new(:invalid_cursor),
    )

    get "/videos/saved/feed.json", params: { cursor: "bad" }

    expect(response.status).to eq(400)
    expect(response.parsed_body).to eq({ "error" => { "code" => "invalid_cursor" } })
  end

  it "returns not found before querying when Video Hub is disabled" do
    sign_in(viewer)
    SiteSetting.video_hub_enabled = false
    VideoHub::SavedFeedQuery.expects(:fetch).never

    get "/videos/saved/feed.json"

    expect(response.status).to eq(404)
  end

  def video_payload(video)
    {
      "id" => video.id,
      "provider" => video.provider,
      "external_id" => video.external_id,
      "canonical_url" => video.canonical_url,
      "kind" => video.kind,
      "title" => video.title,
      "thumbnail_url" => video.thumbnail_url,
      "duration_seconds" => video.duration_seconds,
      "author_name" => video.author_name,
      "topic_id" => video.topic_id,
      "post_id" => video.post_id,
      "published_at" => video.published_at.iso8601,
      "watch_path" => "/videos/#{video.id}/#{video.topic.slug}",
    }
  end

  def create_video(owner:)
    topic = Fabricate(:topic, user: owner, category: Fabricate(:category))
    post = Fabricate(:post, topic: topic, user: owner)

    VideoHub::Video.create!(
      user: owner,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: "saved-feed-request-video",
      canonical_url: "https://www.youtube.com/watch?v=saved-feed-request-video",
      kind: "landscape",
      title: "Saved feed request video",
      status: "published",
      published_at: Time.zone.now,
    )
  end
end
