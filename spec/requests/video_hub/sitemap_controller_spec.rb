# frozen_string_literal: true

describe "Video Hub sitemap canonical URLs" do
  before do
    SiteSetting.enable_sitemap = true
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
    Discourse.cache.delete("sitemap/1/#{SiteSetting.sitemap_page_size}")
  end

  it "replaces only an indexable backing topic URL with its canonical watch URL" do
    video = create_video
    regular_topic = create_topic
    create_page_sitemap

    get "/sitemap_1.xml"

    expect(response.status).to eq(200)
    locations = sitemap_locations
    expect(locations).to include("#{Discourse.base_url}/videos/#{video.id}/#{video.topic.slug}")
    expect(locations).not_to include("#{Discourse.base_url}#{video.topic.relative_url}")
    expect(locations).to include("#{Discourse.base_url}#{regular_topic.relative_url}")
  end

  it "preserves the backing topic URL when its provider is disabled" do
    video = create_video
    SiteSetting.video_hub_youtube_enabled = false
    create_page_sitemap

    get "/sitemap_1.xml"

    expect(sitemap_locations).to include("#{Discourse.base_url}#{video.topic.relative_url}")
    expect(sitemap_locations).not_to include(
      "#{Discourse.base_url}/videos/#{video.id}/#{video.topic.slug}",
    )
  end

  it "preserves the backing topic URL when the mapped video is unavailable" do
    video = create_video(status: "unavailable")
    create_page_sitemap

    get "/sitemap_1.xml"

    expect(sitemap_locations).to include("#{Discourse.base_url}#{video.topic.relative_url}")
    expect(sitemap_locations).not_to include(
      "#{Discourse.base_url}/videos/#{video.id}/#{video.topic.slug}",
    )
  end

  it "does not add topic pagination to a recent sitemap watch URL" do
    video = create_video
    video.topic.update!(posts_count: TopicView.chunk_size + 1, bumped_at: 1.minute.ago)
    sitemap = Sitemap.touch(Sitemap::RECENT_SITEMAP_NAME)
    Discourse.cache.delete("sitemap/recent/#{sitemap.last_posted_at.to_i}")

    get "/sitemap_recent.xml"

    watch_url = "#{Discourse.base_url}/videos/#{video.id}/#{video.topic.slug}"
    expect(sitemap_locations).to include(watch_url)
    expect(sitemap_locations).not_to include("#{watch_url}?page=2")
  end

  it "never exposes a private backing topic through the sitemap" do
    group = Fabricate(:group)
    category = Fabricate(:private_category, group: group)
    video = create_video(category: category)
    create_page_sitemap

    get "/sitemap_1.xml"

    locations = sitemap_locations
    expect(locations).not_to include("#{Discourse.base_url}#{video.topic.relative_url}")
    expect(locations).not_to include(
      "#{Discourse.base_url}/videos/#{video.id}/#{video.topic.slug}",
    )
  end

  def sitemap_locations
    Nokogiri::XML::Document.parse(response.body).css("loc").map(&:text)
  end

  def create_page_sitemap
    Sitemap.create!(name: "1", enabled: true, last_posted_at: 1.minute.ago)
  end

  def create_topic(category: nil)
    @topic_sequence = @topic_sequence.to_i + 1
    user = Fabricate(:user)
    topic =
      Fabricate(
        :topic,
        user: user,
        category: category,
        title: "Video Hub sitemap topic #{@topic_sequence}",
      )
    Fabricate(:post, topic: topic, user: user)
    topic
  end

  def create_video(status: "published", category: nil)
    topic = create_topic(category: category)
    post = topic.posts.find_by(post_number: 1)

    VideoHub::Video.create!(
      user: topic.user,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: "sitemap-video-#{@topic_sequence}",
      canonical_url: "https://www.youtube.com/watch?v=sitemap-video-#{@topic_sequence}",
      kind: "landscape",
      title: "Sitemap video #{@topic_sequence}",
      status: status,
      published_at: Time.zone.now,
    )
  end
end
