# frozen_string_literal: true

describe "Video Hub immersive explore shell" do
  before { SiteSetting.video_hub_enabled = true }

  it "serves the explore shell with aggregate noindex policy" do
    get "/videos/explore"

    expect(response.status).to eq(200)
    expect(response.headers["X-Robots-Tag"]).to eq("noindex,follow")
  end

  it "fails closed when Video Hub is disabled" do
    SiteSetting.video_hub_enabled = false

    get "/videos/explore"

    expect(response.status).to eq(404)
  end
end
