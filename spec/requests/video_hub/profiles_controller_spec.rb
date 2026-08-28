# frozen_string_literal: true

describe VideoHub::ProfilesController do
  let(:profile_user) { Fabricate(:user) }

  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
  end

  it "passes the anonymous viewer to the profile query and serializes the stable profile payload" do
    section = create_section
    video = create_video
    item = create_item(section, video)

    VideoHub::ProfileQuery
      .expects(:fetch)
      .with(user: nil, username: profile_user.username)
      .returns(profile_result(section, item, video))

    get "/videos/profile/#{profile_user.username}.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq(
      {
        "profile" => {
          "username" => profile_user.username,
          "sections" => [
            {
              "id" => section.id,
              "section_type" => "shorts",
              "title" => "Shorts",
              "position" => 0,
              "items" => [
                {
                  "id" => item.id,
                  "position" => 0,
                  "pinned" => true,
                  "video" => video_payload(video),
                },
              ],
            },
          ],
        },
      },
    )
  end

  it "passes the authenticated viewer to the profile query" do
    viewer = Fabricate(:user)
    sign_in(viewer)
    VideoHub::ProfileQuery
      .expects(:fetch)
      .with(user: viewer, username: profile_user.username)
      .returns(VideoHub::ProfileQuery::Result.new(profile_user: profile_user, sections: [].freeze))

    get "/videos/profile/#{profile_user.username}.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body).to eq(
      { "profile" => { "username" => profile_user.username, "sections" => [] } },
    )
  end

  it "preserves not-found semantics for missing or hidden profiles" do
    VideoHub::ProfileQuery.expects(:fetch).raises(Discourse::NotFound)

    get "/videos/profile/#{profile_user.username}.json"

    expect(response.status).to eq(404)
  end

  it "returns not found before querying when Video Hub is disabled" do
    SiteSetting.video_hub_enabled = false
    VideoHub::ProfileQuery.expects(:fetch).never

    get "/videos/profile/#{profile_user.username}.json"

    expect(response.status).to eq(404)
  end

  def profile_result(section, item, video)
    VideoHub::ProfileQuery::Result.new(
      profile_user: profile_user,
      sections: [
        VideoHub::ProfileQuery::SectionResult.new(
          profile_section: section,
          items: [
            VideoHub::ProfileQuery::ItemResult.new(profile_item: item, video: video).freeze,
          ].freeze,
        ).freeze,
      ].freeze,
    ).freeze
  end

  def create_section
    VideoHub::ProfileSection.create!(
      user: profile_user,
      section_type: "shorts",
      title: "Shorts",
      position: 0,
      visible: true,
    )
  end

  def create_item(section, video)
    VideoHub::ProfileItem.create!(
      profile_section: section,
      video: video,
      position: 0,
      pinned: true,
      visible: true,
    )
  end

  def create_video
    author = Fabricate(:user)
    topic = Fabricate(:topic, user: author)
    post = Fabricate(:post, topic: topic, user: author)

    VideoHub::Video.create!(
      user: author,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: "profile-controller-video",
      canonical_url: "https://www.youtube.com/watch?v=profile-controller-video",
      kind: "shorts",
      title: "Profile controller video",
      thumbnail_url: "https://example.com/profile.jpg",
      duration_seconds: 15,
      author_name: "Profile author",
      status: "published",
      published_at: Time.zone.now,
    )
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
end
