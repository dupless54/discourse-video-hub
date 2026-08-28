# frozen_string_literal: true

describe "Video Hub crawl policy" do
  let(:crawler_headers) { { "HTTP_USER_AGENT" => "Googlebot" } }

  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
  end

  it "marks aggregate Video Hub SPA surfaces noindex while keeping links crawlable" do
    user = Fabricate(:user)

    [
      "/videos",
      "/videos/new",
      "/u/#{user.username}/videos",
      "/u/#{user.username}/videos/edit",
    ].each do |path|
      get path, headers: crawler_headers

      expect(response.status).to eq(200), "expected #{path} to render the Discourse SPA shell"
      document = Nokogiri.HTML(response.body)
      robots = document.css('meta[name="robots"]').map { |tag| tag["content"] }
      expect(robots).to include("noindex,follow"), "expected #{path} to be noindex,follow"
    end
  end

  it "does not apply aggregate noindex metadata to the canonical watch page" do
    owner = Fabricate(:user)
    topic = Fabricate(:topic, user: owner, title: "Video Hub crawl policy watch")
    post = Fabricate(:post, topic: topic, user: owner)
    video =
      VideoHub::Video.create!(
        user: owner,
        topic: topic,
        post: post,
        provider: "youtube",
        external_id: "crawl-policy-watch",
        canonical_url: "https://www.youtube.com/watch?v=crawl-policy-watch",
        kind: "landscape",
        title: "Crawl policy watch",
        status: "published",
        published_at: 1.hour.ago,
      )

    get "/videos/#{video.id}/#{topic.slug}", headers: crawler_headers

    expect(response.status).to eq(200)
    document = Nokogiri.HTML(response.body)
    expect(document.css('meta[name="robots"][content="noindex,follow"]')).to be_empty
    expect(document.at_css('link[rel="canonical"]')["href"]).to eq(
      "#{Discourse.base_url}/videos/#{video.id}/#{topic.slug}",
    )
  end

  it "does not emit Video Hub crawl metadata when the plugin is disabled" do
    SiteSetting.video_hub_enabled = false

    get "/videos", headers: crawler_headers

    document = Nokogiri.HTML(response.body)
    expect(document.css('meta[name="robots"][content="noindex,follow"]')).to be_empty
  end
end
