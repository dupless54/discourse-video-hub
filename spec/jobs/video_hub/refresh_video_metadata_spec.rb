# frozen_string_literal: true

describe Jobs::VideoHub::RefreshVideoMetadata do
  it "delegates one bounded video id to the refresh service" do
    VideoHub::RefreshVideoMetadata.expects(:refresh).with(video_id: 42).returns(:refreshed)

    expect(described_class.new.execute(video_id: 42)).to eq(:refreshed)
  end

  it "rejects a missing video id before invoking the service" do
    VideoHub::RefreshVideoMetadata.expects(:refresh).never

    expect { described_class.new.execute({}) }.to raise_error(Discourse::InvalidParameters)
  end
end
