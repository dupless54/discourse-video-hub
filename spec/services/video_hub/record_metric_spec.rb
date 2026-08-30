# frozen_string_literal: true

describe VideoHub::RecordMetric do
  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
  end

  let(:owner) { Fabricate(:user) }
  let(:viewer) { Fabricate(:user) }
  let(:video) { create_published_video(owner) }

  it "records one daily impression per viewer and deduplicates repeats" do
    expect(record(viewer, video, "impression")).to eq(:recorded)
    expect(record(viewer, video, "impression")).to eq(:duplicate)

    metric = VideoHub::DailyMetric.find_by!(video: video, day: Time.zone.today)
    expect(metric.impressions).to eq(1)
    expect(metric.qualified_views).to eq(0)
  end

  it "requires a prior impression and the qualified delay before counting a qualified view" do
    started_at = Time.zone.parse("2026-08-30 01:00:00")

    freeze_time(started_at) do
      expect(record(viewer, video, "qualified_view")).to eq(:ignored)
      expect(record(viewer, video, "impression")).to eq(:recorded)
      expect(record(viewer, video, "qualified_view")).to eq(:ignored)
    end

    freeze_time(started_at + 4.seconds) do
      expect(record(viewer, video, "qualified_view")).to eq(:recorded)
      expect(record(viewer, video, "qualified_view")).to eq(:duplicate)
    end

    metric = VideoHub::DailyMetric.find_by!(video: video, day: started_at.to_date)
    expect(metric.impressions).to eq(1)
    expect(metric.qualified_views).to eq(1)
  end

  it "does not allow the video owner to boost their own aggregate" do
    expect(record(owner, video, "impression")).to eq(:ignored)
    expect(VideoHub::DailyMetric.where(video: video)).to be_empty
  end

  it "fails closed when the viewer cannot see the backing topic" do
    group = Fabricate(:group)
    category = Fabricate(:private_category, group: group)
    private_video = create_published_video(owner, category: category)

    expect { record(viewer, private_video, "impression") }.to raise_error(Discourse::NotFound)
    expect(VideoHub::DailyMetric.where(video: private_video)).to be_empty
  end

  it "rejects unknown metric names without writing aggregate state" do
    expect { record(viewer, video, "completion") }.to raise_error(described_class::MetricError) do |error|
      expect(error.code).to eq(:invalid_event)
    end
    expect(VideoHub::DailyMetric.where(video: video)).to be_empty
  end

  def record(user, target_video, event)
    described_class.record(user: user, video_id: target_video.id, event: event)
  end

  def create_published_video(owner, category: nil)
    topic = Fabricate(:topic, user: owner, category: category)
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
