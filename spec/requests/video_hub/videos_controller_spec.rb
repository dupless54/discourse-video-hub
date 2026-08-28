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

  describe "GET /videos/:id/:slug.json" do
    it "loads the watch record for an anonymous viewer and returns the canonical core-derived path" do
      video = create_published_video(Fabricate(:user))
      VideoHub::WatchQuery
        .expects(:fetch)
        .with(user: nil, id: video.id.to_s)
        .returns(VideoHub::WatchQuery::Result.new(video: video, slug: video.topic.slug))

      get "/videos/#{video.id}/wrong-slug.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq({ "video" => video_payload(video) })
    end

    it "preserves not-found semantics from the watch query" do
      video = create_published_video(Fabricate(:user))
      VideoHub::WatchQuery.expects(:fetch).raises(Discourse::NotFound)

      get "/videos/#{video.id}/hidden.json"

      expect(response.status).to eq(404)
    end

    it "does not invoke the watch query for a non-numeric route identifier" do
      VideoHub::WatchQuery.expects(:fetch).never

      get "/videos/not-an-id/video.json"

      expect(response.status).to eq(404)
    end

    it "returns not found before querying when the plugin is disabled" do
      video = create_published_video(Fabricate(:user))
      SiteSetting.video_hub_enabled = false
      VideoHub::WatchQuery.expects(:fetch).never

      get "/videos/#{video.id}/#{video.topic.slug}.json"

      expect(response.status).to eq(404)
    end
  end

  describe "GET /videos/:id/:slug" do
    let(:crawler_headers) { { "HTTP_USER_AGENT" => "Googlebot" } }

    it "renders one canonical URL with escaped Open Graph and VideoObject metadata" do
      video = create_seo_video
      canonical_url = "#{Discourse.base_url}/videos/#{video.id}/#{video.topic.slug}"

      get "/videos/#{video.id}/#{video.topic.slug}", headers: crawler_headers

      expect(response.status).to eq(200)
      document = Nokogiri::HTML(response.body)
      canonical_links = document.css('link[rel="canonical"]')
      expect(canonical_links.length).to eq(1)
      expect(canonical_links.first["href"]).to eq(canonical_url)
      expect(document.at_css("title").text).to include(video.title)
      expect(document.at_css('meta[name="description"]')["content"]).to eq(video.description)
      expect(document.at_css('meta[property="og:url"]')["content"]).to eq(canonical_url)
      expect(document.at_css('meta[property="og:title"]')["content"]).to eq(video.title)
      expect(document.at_css('meta[property="og:description"]')["content"]).to eq(video.description)
      expect(document.at_css('meta[property="og:image"]')["content"]).to eq(video.thumbnail_url)
      expect(document.at_css(".video-hub-crawler h1").text).to eq(video.title)
      expect(document.at_css(".video-hub-crawler p").text).to eq(video.description)

      schema = JSON.parse(document.at_css('script[type="application/ld+json"]').text)
      expect(schema).to include(
        "@context" => "https://schema.org",
        "@type" => "VideoObject",
        "name" => video.title,
        "description" => video.description,
        "url" => canonical_url,
        "contentUrl" => video.canonical_url,
        "duration" => "PT90S",
      )
      expect(schema["thumbnailUrl"]).to eq([video.thumbnail_url])
      expect(schema["uploadDate"]).to eq(video.published_at.iso8601)
    end

    it "permanently redirects a wrong slug to the canonical watch URL" do
      video = create_seo_video
      canonical_url = "#{Discourse.base_url}/videos/#{video.id}/#{video.topic.slug}"

      get "/videos/#{video.id}/wrong-slug", headers: crawler_headers

      expect(response.status).to eq(301)
      expect(response.headers["Location"]).to eq(canonical_url)
    end

    it "keeps hostile provider metadata inside escaped text and JSON" do
      hostile_title = "Bad </script><script data-evil>boom</script>"
      hostile_description = "Description </script><script data-evil>boom</script>"
      video = create_seo_video(title: hostile_title, description: hostile_description)

      get "/videos/#{video.id}/#{video.topic.slug}", headers: crawler_headers

      expect(response.status).to eq(200)
      document = Nokogiri::HTML(response.body)
      expect(document.css("script[data-evil]")).to be_empty
      expect(document.at_css('meta[property="og:title"]')["content"]).to eq(hostile_title)
      expect(document.at_css('meta[property="og:description"]')["content"]).to eq(
        hostile_description,
      )
      schema = JSON.parse(document.at_css('script[type="application/ld+json"]').text)
      expect(schema["name"]).to eq(hostile_title)
      expect(schema["description"]).to eq(hostile_description)
      expect(document.at_css(".video-hub-crawler h1").text).to eq(hostile_title)
    end

    it "returns not found without leaking metadata from a private backing topic" do
      marker = "PRIVATE-VIDEO-SEO-MARKER"
      group = Fabricate(:group)
      category = Fabricate(:private_category, group: group)
      owner = Fabricate(:user)
      topic = Fabricate(:topic, user: owner, category: category)
      post = Fabricate(:post, topic: topic, user: owner)
      video =
        VideoHub::Video.create!(
          user: owner,
          topic: topic,
          post: post,
          provider: "youtube",
          external_id: "private-seo-video",
          canonical_url: "https://www.youtube.com/watch?v=private-seo-video",
          kind: "landscape",
          title: marker,
          description: "#{marker}-DESCRIPTION",
          thumbnail_url: "https://cdn.example.com/private.jpg",
          duration_seconds: 90,
          author_name: "Private creator",
          status: "published",
          published_at: Time.zone.now,
        )

      get "/videos/#{video.id}/#{video.topic.slug}", headers: crawler_headers

      expect(response.status).to eq(404)
      expect(response.body).not_to include(marker)
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
      "watch_path" => "/videos/#{video.id}/#{video.topic.slug}",
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

  def create_seo_video(**overrides)
    @seo_video_sequence = @seo_video_sequence.to_i + 1
    owner = Fabricate(:user)
    topic = Fabricate(:topic, user: owner, title: "SEO topic #{@seo_video_sequence}")
    post = Fabricate(:post, topic: topic, user: owner)

    VideoHub::Video.create!(
      {
        user: owner,
        topic: topic,
        post: post,
        provider: "youtube",
        external_id: "request-seo-video-#{@seo_video_sequence}",
        canonical_url: "https://www.youtube.com/watch?v=request-seo-video-#{@seo_video_sequence}",
        kind: "landscape",
        title: "SEO video #{@seo_video_sequence}",
        description: "SEO description #{@seo_video_sequence}",
        thumbnail_url: "https://cdn.example.com/seo-#{@seo_video_sequence}.jpg",
        duration_seconds: 90,
        author_name: "SEO creator",
        status: "published",
        published_at: Time.zone.now,
      }.merge(overrides),
    )
  end
end
