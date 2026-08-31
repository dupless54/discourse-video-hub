# frozen_string_literal: true

describe VideoHub::FollowingFeedCursor do
  let(:published_at) { Time.zone.parse("2026-08-31 08:00:00.123456") }

  it "round trips a signed following-feed position" do
    token = described_class.encode(published_at: published_at, video_id: 42)
    decoded = described_class.decode(token)

    expect(decoded.published_at).to eq_time(published_at)
    expect(decoded.video_id).to eq(42)
  end

  it "rejects tampered tokens" do
    token = described_class.encode(published_at: published_at, video_id: 42)
    tampered = token.dup
    tampered[-1] = tampered[-1] == "a" ? "b" : "a"

    expect { described_class.decode(tampered) }.to raise_error(described_class::CursorError) do |error|
      expect(error.code).to eq(:invalid_cursor)
    end
  end

  it "rejects malformed, whitespace, and oversized tokens" do
    ["", "bad token", "x" * (described_class::MAX_LENGTH + 1)].each do |token|
      expect { described_class.decode(token) }.to raise_error(described_class::CursorError) do |error|
        expect(error.code).to eq(:invalid_cursor)
      end
    end
  end

  it "rejects nonpositive video ids" do
    expect { described_class.encode(published_at: published_at, video_id: 0) }.to raise_error(
      described_class::CursorError,
    ) { |error| expect(error.code).to eq(:invalid_cursor) }
  end
end
