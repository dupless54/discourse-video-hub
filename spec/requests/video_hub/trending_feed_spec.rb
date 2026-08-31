# frozen_string_literal: true

describe "Video Hub trending feed" do
  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_tiktok_enabled = false
    SiteSetting.video_hub_instagram_enabled = false
  end

  it "serves the public trending feed with the standard video payload" do
    video = create_video
    VideoHub::TrendingFeedQuery
      .expects(:fetch)
      .with(user: nil, cursor: "trend-cursor", limit: "1")
      .returns(
        VideoHub::TrendingFeedQuery::Result.new(
          videos: [video],
          has_more: true,
          next_cursor: "next-trend-cursor",
        ),
      )

    get "/videos/trending/feed.json", params: { cursor: "trend-cursor", limit: 1 }

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq(
      {
        "videos" => [
          {
            "id" => video.id,
            "provider" => "youtube",
            "external_id" => video.external_id,
            "canonical_url" => video.canonical_url,
            "kind" => "landscape",
            "title" => video.title,
            "thumbnail_url" => nil,
            "duration_seconds" => nil,
            "author_name" => "Trending author",
            "topic_id" => video.topic_id,
            "post_id" => video.post_id,
            "published_at" => video.published_at.iso8601,
            "watch_path" => "/videos/#{video.id}/#{video.topic.slug}",
          },
        ],
        "providers" => ["youtube"],
        "pagination" => {
          "has_more" => true,
          "next_cursor" => "next-trend-cursor",
        },
      },
    )
  end

  it "maps malformed trending cursor input to a safe bad request" do
    VideoHub::TrendingFeedQuery.expects(:fetch).raises(
      VideoHub::TrendingFeedQuery::FeedError.new(:invalid_cursor),
    )

    get "/videos/trending/feed.json", params: { cursor: "bad" }

    expect(response.status).to eq(400)
    expect(response.parsed_body).to eq({ "error" => { "code" => "invalid_cursor" } })
  end

  it "returns not found before querying when Video Hub is disabled" do
    SiteSetting.video_hub_enabled = false
    VideoHub::TrendingFeedQuery.expects(:fetch).never

    get "/videos/trending/feed.json"

    expect(response.status).to eq(404)
  end

  def create_video
    owner = Fabricate(:user)
    category = Fabricate(:category)
    topic = Fabricate(:topic, user: owner, category: category)
    post = Fabricate(:post, topic: topic, user: owner)

    VideoHub::Video.create!(
      user: owner,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: "trending-endpoint-video",
      canonical_url: "https://www.youtube.com/watch?v=trending-endpoint-video",
      kind: "landscape",
      title: "Trending endpoint video",
      thumbnail_url: nil,
      duration_seconds: nil,
      author_name: "Trending author",
      status: "published",
      published_at: 1.hour.ago,
    )
  end
end
