# frozen_string_literal: true

describe Jobs::VideoHub::PruneDailyMetrics do
  it "keeps only the configured bounded retention window" do
    freeze_time(Time.zone.parse("2026-08-30 01:00:00")) do
      video = create_published_video(Fabricate(:user))
      expired = create_metric(video, VideoHub::DailyMetric::RETENTION_DAYS.days.ago.to_date - 1.day)
      boundary = create_metric(video, VideoHub::DailyMetric::RETENTION_DAYS.days.ago.to_date)
      recent = create_metric(video, 1.day.ago.to_date)

      described_class.new.execute({})

      expect(VideoHub::DailyMetric.exists?(expired.id)).to eq(false)
      expect(VideoHub::DailyMetric.exists?(boundary.id)).to eq(true)
      expect(VideoHub::DailyMetric.exists?(recent.id)).to eq(true)
    end
  end

  def create_metric(video, day)
    VideoHub::DailyMetric.create!(video: video, day: day, impressions: 1)
  end

  def create_published_video(owner)
    topic = Fabricate(:topic, user: owner)
    post = Fabricate(:post, topic: topic, user: owner)
    external_id = SecureRandom.hex(8)

    VideoHub::Video.create!(
      user: owner,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: external_id,
      canonical_url: "https://www.youtube.com/watch?v=#{external_id}",
      kind: "landscape",
      status: "published",
      published_at: Time.zone.now,
    )
  end
end
