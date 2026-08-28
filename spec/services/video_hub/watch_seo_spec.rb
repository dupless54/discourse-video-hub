# frozen_string_literal: true

describe VideoHub::WatchSeo do
  it "builds canonical metadata and a VideoObject from safe published metadata" do
    video =
      create_video(
        description: "A useful video description",
        thumbnail_url: "https://cdn.example.com/video.jpg",
        duration_seconds: 90,
        author_name: "Example creator",
      )

    result = described_class.build(video: video, slug: video.topic.slug)

    expect(result.title).to eq(video.title)
    expect(result.document_title).to eq("#{video.title} - #{SiteSetting.title}")
    expect(result.description).to eq("A useful video description")
    expect(result.canonical_path).to eq("/videos/#{video.id}/#{video.topic.slug}")
    expect(result.canonical_url).to eq("#{Discourse.base_url}#{result.canonical_path}")
    expect(result.image_url).to eq("https://cdn.example.com/video.jpg")
    expect(result.source_url).to eq(video.canonical_url)
    expect(result.json_ld).to eq(
      {
        "@context" => "https://schema.org",
        "@type" => "VideoObject",
        "name" => video.title,
        "description" => "A useful video description",
        "thumbnailUrl" => ["https://cdn.example.com/video.jpg"],
        "uploadDate" => video.published_at.iso8601,
        "url" => result.canonical_url,
        "contentUrl" => video.canonical_url,
        "duration" => "PT90S",
        "author" => {
          "@type" => "Person",
          "name" => "Example creator",
        },
      },
    )
  end

  it "falls back to the backing topic title and omits VideoObject without a thumbnail" do
    video = create_video(title: nil, description: nil, thumbnail_url: nil)

    result = described_class.build(video: video, slug: video.topic.slug)

    expect(result.title).to eq(video.topic.title)
    expect(result.description).to eq(video.topic.title)
    expect(result.image_url).to be_nil
    expect(result.json_ld).to be_nil
  end

  it "rejects non-http image and source URLs from structured metadata" do
    video =
      create_video(
        canonical_url: "javascript:alert(1)",
        thumbnail_url: "https://cdn.example.com/video.jpg",
      )

    result = described_class.build(video: video, slug: video.topic.slug)

    expect(result.source_url).to be_nil
    expect(result.json_ld).not_to have_key("contentUrl")

    video.update_column(:thumbnail_url, "data:text/html,unsafe")
    result = described_class.build(video: video, slug: video.topic.slug)

    expect(result.image_url).to be_nil
    expect(result.json_ld).to be_nil
  end

  def create_video(**overrides)
    @video_sequence = @video_sequence.to_i + 1
    owner = Fabricate(:user)
    topic = Fabricate(:topic, user: owner, title: "Video Hub SEO topic #{@video_sequence}")
    post = Fabricate(:post, topic: topic, user: owner)

    VideoHub::Video.create!(
      {
        user: owner,
        topic: topic,
        post: post,
        provider: "youtube",
        external_id: "seo-video-#{@video_sequence}",
        canonical_url: "https://www.youtube.com/watch?v=seo-video-#{@video_sequence}",
        kind: "landscape",
        title: "SEO video #{@video_sequence}",
        description: nil,
        thumbnail_url: "https://cdn.example.com/default.jpg",
        duration_seconds: nil,
        author_name: nil,
        status: "published",
        published_at: Time.zone.now,
      }.merge(overrides),
    )
  end
end
