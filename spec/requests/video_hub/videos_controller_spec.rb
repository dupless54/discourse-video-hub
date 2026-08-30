# frozen_string_literal: true

describe VideoHub::VideosController do
  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_tiktok_enabled = true
    SiteSetting.video_hub_instagram_enabled = false
  end

  describe "GET /videos/feed.json" do
    it "passes the anonymous viewer and bounded defaults to the feed query" do
      VideoHub::FeedQuery
        .expects(:fetch)
        .with(user: nil, cursor: nil, limit: VideoHub::FeedQuery::DEFAULT_LIMIT)
        .returns(empty_feed_result)

      get "/videos/feed.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(
        {
          "videos" => [],
          "providers" => %w[youtube tiktok],
          "pagination" => {
            "has_more" => false,
            "next_cursor" => nil,
          },
        },
      )
    end

    it "passes the authenticated viewer, cursor, and limit and serializes the stable feed payload" do
      user = Fabricate(:user)
      video = create_published_video(user)
      sign_in(user)
      VideoHub::FeedQuery
        .expects(:fetch)
        .with(user: user, cursor: "cursor-token", limit: "2")
        .returns(
          VideoHub::FeedQuery::Result.new(
            videos: [video],
            has_more: true,
            next_cursor: "next-token",
          ),
        )

      get "/videos/feed.json", params: { cursor: "cursor-token", limit: 2 }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(
        {
          "videos" => [video_payload(video)],
          "providers" => %w[youtube tiktok],
          "pagination" => {
            "has_more" => true,
            "next_cursor" => "next-token",
          },
        },
      )
    end

    it "reflects provider feature settings without exposing disabled providers" do
      SiteSetting.video_hub_tiktok_enabled = false
      SiteSetting.video_hub_instagram_enabled = true
      VideoHub::FeedQuery.stubs(:fetch).returns(empty_feed_result)

      get "/videos/feed.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["providers"]).to eq(%w[youtube instagram])
    end

    it "maps malformed feed inputs to a safe bad request" do
      VideoHub::FeedQuery.expects(:fetch).raises(
        VideoHub::FeedQuery::FeedError.new(:invalid_cursor),
      )

      get "/videos/feed.json", params: { cursor: "bad" }

      expect(response.status).to eq(400)
      expect(response.parsed_body).to eq({ "error" => { "code" => "invalid_cursor" } })
    end

    it "returns not found before querying when the plugin is disabled" do
      SiteSetting.video_hub_enabled = false
      VideoHub::FeedQuery.expects(:fetch).never

      get "/videos/feed.json"

      expect(response.status).to eq(404)
    end
  end

  describe "POST /videos" do
    let(:user) { Fabricate(:user) }
    let(:input_url) { "https://www.youtube.com/watch?v=dQw4w9WgXcQ" }

    it "requires login before invoking the publisher" do
      VideoHub::PublishVideo.expects(:publish).never

      post "/videos", params: { url: input_url }

      expect(response.status).to eq(403)
    end

    it "requires a URL before invoking the publisher" do
      sign_in(user)
      VideoHub::PublishVideo.expects(:publish).never

      post "/videos", params: { caption: "Missing URL" }

      expect(response.status).to eq(400)
    end

    it "passes only the authenticated user, URL, and optional caption to the publisher" do
      sign_in(user)
      video = create_published_video(user)
      VideoHub::PublishVideo
        .expects(:publish)
        .with(user: user, url: input_url, caption: "My caption")
        .returns(video)

      post "/videos",
           params: {
             url: input_url,
             caption: "My caption",
             provider: "instagram",
             category_id: 999_999,
             trust_level: 4,
           }

      expect(response.status).to eq(201)
      expect(response.parsed_body).to eq({ "video" => video_payload(video) })
    end

    it "maps safe validation failures to unprocessable entity" do
      sign_in(user)
      VideoHub::PublishVideo.expects(:publish).raises(
        VideoHub::PublishVideo::PublishError.new(:invalid_caption),
      )

      post "/videos", params: { url: input_url, caption: "bad" }

      expect(response.status).to eq(422)
      expect(response.parsed_body).to eq({ "error" => { "code" => "invalid_caption" } })
    end

    it "maps publish authorization failures to forbidden" do
      sign_in(user)
      VideoHub::PublishVideo.expects(:publish).raises(
        VideoHub::PublishVideo::PublishError.new(:insufficient_trust),
      )

      post "/videos", params: { url: input_url }

      expect(response.status).to eq(403)
      expect(response.parsed_body).to eq({ "error" => { "code" => "insufficient_trust" } })
    end

    it "maps missing server category configuration to service unavailable" do
      sign_in(user)
      VideoHub::PublishVideo.expects(:publish).raises(
        VideoHub::PublishVideo::PublishError.new(:category_not_configured),
      )

      post "/videos", params: { url: input_url }

      expect(response.status).to eq(503)
      expect(response.parsed_body).to eq({ "error" => { "code" => "category_not_configured" } })
    end

    it "maps internal persistence failure to a safe server error" do
      sign_in(user)
      VideoHub::PublishVideo.expects(:publish).raises(
        VideoHub::PublishVideo::PublishError.new(:publish_failed),
      )

      post "/videos", params: { url: input_url }

      expect(response.status).to eq(500)
      expect(response.parsed_body).to eq({ "error" => { "code" => "publish_failed" } })
    end

    it "preserves not-found semantics for invisible canonical duplicates" do
      sign_in(user)
      VideoHub::PublishVideo.expects(:publish).raises(Discourse::NotFound)

      post "/videos", params: { url: input_url }

      expect(response.status).to eq(404)
    end

    it "does not invoke the publisher when Video Hub is disabled" do
      sign_in(user)
      SiteSetting.video_hub_enabled = false
      VideoHub::PublishVideo.expects(:publish).never

      post "/videos", params: { url: input_url }

      expect(response.status).to eq(404)
    end
  end

  def empty_feed_result
    VideoHub::FeedQuery::Result.new(videos: [], has_more: false, next_cursor: nil)
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
    }
  end

  def create_published_video(user)
    topic = Fabricate(:topic, user: user)
    post = Fabricate(:post, topic: topic, user: user)

    VideoHub::Video.create!(
      user: user,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: "dQw4w9WgXcQ",
      canonical_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      kind: "landscape",
      title: "A published video",
      thumbnail_url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
      duration_seconds: nil,
      author_name: "Example creator",
      status: "published",
      published_at: Time.zone.now,
    )
  end
end
