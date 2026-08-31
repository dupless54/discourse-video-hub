# frozen_string_literal: true

describe "Video Hub following feed" do
  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
  end

  let(:viewer) { Fabricate(:user) }
  let(:owner) { Fabricate(:user) }
  let(:video) { create_video(owner: owner) }

  it "requires login before querying followed videos" do
    VideoHub::FollowingFeedQuery.expects(:fetch).never

    get "/videos/following/feed.json"

    expect(response.status).to eq(403)
  end

  it "passes the authenticated viewer and bounded pagination inputs to the following query" do
    sign_in(viewer)
    VideoHub::FollowingFeedQuery
      .expects(:fetch)
      .with(user: viewer, cursor: "cursor-token", limit: "2")
      .returns(
        VideoHub::FollowingFeedQuery::Result.new(
          videos: [video],
          has_more: true,
          next_cursor: "next-token",
        ),
      )

    get "/videos/following/feed.json", params: { cursor: "cursor-token", limit: 2 }

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq(
      {
        "videos" => [video_payload(video)],
        "pagination" => {
          "has_more" => true,
          "next_cursor" => "next-token",
        },
      },
    )
  end

  it "returns not found when the official follow integration is unavailable" do
    sign_in(viewer)
    VideoHub::FollowingFeedQuery.expects(:fetch).raises(
      VideoHub::FollowingFeedQuery::FeedError.new(:follow_unavailable),
    )

    get "/videos/following/feed.json"

    expect(response.status).to eq(404)
  end

  it "maps malformed following-feed inputs to a safe bad request" do
    sign_in(viewer)
    VideoHub::FollowingFeedQuery.expects(:fetch).raises(
      VideoHub::FollowingFeedQuery::FeedError.new(:invalid_cursor),
    )

    get "/videos/following/feed.json", params: { cursor: "bad" }

    expect(response.status).to eq(400)
    expect(response.parsed_body).to eq({ "error" => { "code" => "invalid_cursor" } })
  end

  it "returns not found before querying when Video Hub is disabled" do
    sign_in(viewer)
    SiteSetting.video_hub_enabled = false
    VideoHub::FollowingFeedQuery.expects(:fetch).never

    get "/videos/following/feed.json"

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
      external_id: "following-feed-request-video",
      canonical_url: "https://www.youtube.com/watch?v=following-feed-request-video",
      kind: "landscape",
      title: "Following feed request video",
      status: "published",
      published_at: Time.zone.now,
    )
  end
end
