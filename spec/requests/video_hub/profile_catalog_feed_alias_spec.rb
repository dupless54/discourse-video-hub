# frozen_string_literal: true

describe "Video Hub profile catalog feed alias" do
  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_tiktok_enabled = false
    SiteSetting.video_hub_instagram_enabled = false
  end

  it "serves the profile editor catalog from /videos.json" do
    user = Fabricate(:user)
    sign_in(user)

    VideoHub::FeedQuery
      .expects(:fetch)
      .with(user: user, cursor: nil, limit: "20")
      .returns(
        VideoHub::FeedQuery::Result.new(
          videos: [],
          has_more: false,
          next_cursor: nil,
        ),
      )

    get "/videos.json", params: { limit: 20 }

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq(
      {
        "videos" => [],
        "providers" => ["youtube"],
        "pagination" => {
          "has_more" => false,
          "next_cursor" => nil,
        },
      },
    )
  end
end
