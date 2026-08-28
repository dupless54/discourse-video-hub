# frozen_string_literal: true

describe "Video Hub terminal watch SEO" do
  let(:crawler_headers) { { "HTTP_USER_AGENT" => "Googlebot" } }

  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_instagram_enabled = false
  end

  it "returns gone with noindex for a previously published public unavailable video" do
    marker = "UNAVAILABLE-VIDEO-SEO-MARKER"
    video = create_unavailable_video(title: marker)

    get "/videos/#{video.id}/#{video.topic.slug}", headers: crawler_headers

    expect(response.status).to eq(410)
    expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    expect(response.body).not_to include(marker)
    expect(response.body).not_to include(video.canonical_url)
  end

  it "keeps a private unavailable video indistinguishable from not found" do
    marker = "PRIVATE-UNAVAILABLE-VIDEO-MARKER"
    group = Fabricate(:group)
    category = Fabricate(:private_category, group: group)
    video = create_unavailable_video(title: marker, category: category)

    get "/videos/#{video.id}/#{video.topic.slug}", headers: crawler_headers

    expect(response.status).to eq(404)
    expect(response.body).not_to include(marker)
    expect(response.body).not_to include(video.canonical_url)
  end

  it "keeps a disabled-provider unavailable video indistinguishable from not found" do
    video = create_unavailable_video(provider: "instagram")

    get "/videos/#{video.id}/#{video.topic.slug}", headers: crawler_headers

    expect(response.status).to eq(404)
  end

  it "preserves the JSON watch endpoint's existing not-found contract" do
    video = create_unavailable_video

    get "/videos/#{video.id}/#{video.topic.slug}.json"

    expect(response.status).to eq(404)
  end

  def create_unavailable_video(title: "Unavailable video", provider: "youtube", category: nil)
    @video_sequence = @video_sequence.to_i + 1
    owner = Fabricate(:user)
    topic =
      Fabricate(
        :topic,
        user: owner,
        category: category,
        title: "Video Hub terminal SEO #{@video_sequence}",
      )
    post = Fabricate(:post, topic: topic, user: owner)

    VideoHub::Video.create!(
      user: owner,
      topic: topic,
      post: post,
      provider: provider,
      external_id: "terminal-seo-#{@video_sequence}",
      canonical_url: "https://example.com/terminal-seo-#{@video_sequence}",
      kind: "landscape",
      title: title,
      status: "unavailable",
      published_at: 1.hour.ago,
    )
  end
end
