# frozen_string_literal: true

describe VideoHub::DailyMetric do
  let(:video) { create_published_video(Fabricate(:user)) }

  it "accepts bounded counters and one aggregate row per video/day" do
    metric = described_class.create!(video: video, day: Time.zone.today, impressions: 2, qualified_views: 1)

    expect(metric).to be_persisted
    duplicate = described_class.new(video: video, day: metric.day)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:day]).to be_present
  end

  it "rejects negative counters and qualified views above impressions" do
    negative = described_class.new(video: video, day: Time.zone.today, impressions: -1)
    impossible = described_class.new(video: video, day: Time.zone.today, impressions: 1, qualified_views: 2)

    expect(negative).not_to be_valid
    expect(impossible).not_to be_valid
  end

  def create_published_video(owner)
    topic = Fabricate(:topic, user: owner)
    post = Fabricate(:post, topic: topic, user: owner)

    VideoHub::Video.create!(
      user: owner,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: SecureRandom.hex(8),
      canonical_url: "https://www.youtube.com/watch?v=#{SecureRandom.hex(8)}",
      kind: "landscape",
      status: "published",
      published_at: Time.zone.now,
    )
  end
end
