# frozen_string_literal: true

describe VideoHub::VideosController do
  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_tiktok_enabled = true
    SiteSetting.video_hub_instagram_enabled = false
  end

  it "returns an empty, cursor-ready feed with enabled providers" do
    get "/videos/feed.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq(
      "videos" => [],
      "providers" => %w[youtube tiktok],
      "pagination" => { "has_more" => false, "next_cursor" => nil },
    )
  end

  it "reflects provider feature settings without exposing disabled providers" do
    SiteSetting.video_hub_tiktok_enabled = false
    SiteSetting.video_hub_instagram_enabled = true

    get "/videos/feed.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["providers"]).to eq(%w[youtube instagram])
  end

  it "returns not found when the plugin is disabled" do
    SiteSetting.video_hub_enabled = false

    get "/videos/feed.json"

    expect(response.status).to eq(404)
  end
end
