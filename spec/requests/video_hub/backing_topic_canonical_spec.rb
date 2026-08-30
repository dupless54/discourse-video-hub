# frozen_string_literal: true

describe "Video Hub backing topic canonical" do
  let(:crawler_headers) { { "HTTP_USER_AGENT" => "Googlebot" } }

  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
  end

  it "declares the canonical watch URL for a visible published backing topic" do
    video = create_video

    get video.topic.relative_url, headers: crawler_headers

    expect(response.status).to eq(200)
    document = Nokogiri.HTML(response.body)
    canonical_links = document.css('link[rel="canonical"]')
    expect(canonical_links.length).to eq(1)
    expect(canonical_links.first["href"]).to eq(
      "#{Discourse.base_url}/videos/#{video.id}/#{video.topic.slug}",
    )
  end

  it "preserves the core topic canonical for an unrelated topic" do
    topic = create_topic

    get topic.relative_url, headers: crawler_headers

    expect(response.status).to eq(200)
    document = Nokogiri.HTML(response.body)
    expect(document.at_css('link[rel="canonical"]')["href"]).to eq(
      "#{Discourse.base_url}#{topic.relative_url}",
    )
  end

  it "preserves the core topic canonical when the mapped video is unavailable" do
    video = create_video(status: "unavailable")

    get video.topic.relative_url, headers: crawler_headers

    expect(response.status).to eq(200)
    document = Nokogiri.HTML(response.body)
    expect(document.at_css('link[rel="canonical"]')["href"]).to eq(
      "#{Discourse.base_url}#{video.topic.relative_url}",
    )
  end

  it "preserves the core topic canonical when the provider is disabled" do
    video = create_video
    SiteSetting.video_hub_youtube_enabled = false

    get video.topic.relative_url, headers: crawler_headers

    expect(response.status).to eq(200)
    document = Nokogiri.HTML(response.body)
    expect(document.at_css('link[rel="canonical"]')["href"]).to eq(
      "#{Discourse.base_url}#{video.topic.relative_url}",
    )
  end

  it "preserves the core topic canonical when Video Hub is disabled" do
    video = create_video
    SiteSetting.video_hub_enabled = false

    get video.topic.relative_url, headers: crawler_headers

    expect(response.status).to eq(200)
    document = Nokogiri.HTML(response.body)
    expect(document.at_css('link[rel="canonical"]')["href"]).to eq(
      "#{Discourse.base_url}#{video.topic.relative_url}",
    )
  end

  def create_topic
    @topic_sequence = @topic_sequence.to_i + 1
    user = Fabricate(:user)
    topic = Fabricate(:topic, user: user, title: "Video Hub canonical topic #{@topic_sequence}")
    Fabricate(:post, topic: topic, user: user)
    topic
  end

  def create_video(status: "published")
    topic = create_topic
    post = topic.posts.find_by(post_number: 1)

    VideoHub::Video.create!(
      user: topic.user,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: "backing-canonical-#{@topic_sequence}",
      canonical_url: "https://www.youtube.com/watch?v=backing-canonical-#{@topic_sequence}",
      kind: "landscape",
      title: "Backing canonical video #{@topic_sequence}",
      status: status,
      published_at: Time.zone.now,
    )
  end
end
