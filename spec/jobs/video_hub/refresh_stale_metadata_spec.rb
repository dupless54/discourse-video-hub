# frozen_string_literal: true

describe Jobs::VideoHub::RefreshStaleMetadata do
  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_tiktok_enabled = false
    SiteSetting.video_hub_instagram_enabled = false
  end

  it "does nothing while Video Hub is disabled" do
    SiteSetting.video_hub_enabled = false
    Jobs.expects(:enqueue).never

    expect(described_class.new.execute({})).to be_nil
  end

  it "enqueues only stale published videos for enabled providers in backfill-first order" do
    old_stale = create_video(metadata_refreshed_at: 3.days.ago)
    newer_stale = create_video(metadata_refreshed_at: 2.days.ago)
    backfill = create_video(metadata_refreshed_at: nil)
    create_video(metadata_refreshed_at: 1.hour.ago)
    create_video(provider: "tiktok", metadata_refreshed_at: 3.days.ago)
    create_video(metadata_refreshed_at: 3.days.ago, status: "unavailable")

    expect(described_class.new.candidate_ids).to eq([backfill.id, old_stale.id, newer_stale.id])

    sequence = sequence("metadata refresh enqueue")
    Jobs
      .expects(:enqueue)
      .with(Jobs::VideoHub::RefreshVideoMetadata, video_id: backfill.id)
      .in_sequence(sequence)
    Jobs
      .expects(:enqueue)
      .with(Jobs::VideoHub::RefreshVideoMetadata, video_id: old_stale.id)
      .in_sequence(sequence)
    Jobs
      .expects(:enqueue)
      .with(Jobs::VideoHub::RefreshVideoMetadata, video_id: newer_stale.id)
      .in_sequence(sequence)

    described_class.new.execute({})
  end

  it "returns no candidates when every provider is disabled" do
    SiteSetting.video_hub_youtube_enabled = false
    Jobs.expects(:enqueue).never

    job = described_class.new

    expect(job.candidate_ids).to eq([])
    expect(job.execute({})).to be_nil
  end

  def create_video(provider: "youtube", metadata_refreshed_at:, status: "published")
    owner = Fabricate(:user)
    topic = Fabricate(:topic, user: owner)
    post = Fabricate(:post, topic: topic, user: owner)
    external_id = "#{provider}-#{SecureRandom.hex(6)}"

    VideoHub::Video.create!(
      user: owner,
      topic: topic,
      post: post,
      provider: provider,
      external_id: external_id,
      canonical_url: "https://example.test/#{provider}/#{external_id}",
      kind: "landscape",
      title: "Metadata sweep test",
      status: status,
      published_at: 4.days.ago,
      metadata_refreshed_at: metadata_refreshed_at,
    )
  end
end
