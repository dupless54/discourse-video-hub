# frozen_string_literal: true

describe VideoHub::SavedFeedCursor do
  let(:saved_at) { Time.utc(2026, 8, 31, 2, 15, 30, 123_456) }

  it "round trips the saved ordering boundary" do
    token = described_class.encode(saved_at: saved_at, bookmark_id: 42)
    decoded = described_class.decode(token)

    expect(decoded.saved_at).to eq_time(saved_at)
    expect(decoded.bookmark_id).to eq(42)
  end

  it "rejects a tampered cursor" do
    token = described_class.encode(saved_at: saved_at, bookmark_id: 42)
    replacement = token.end_with?("a") ? "b" : "a"
    tampered = "#{token[0...-1]}#{replacement}"

    expect { described_class.decode(tampered) }.to raise_error(
      VideoHub::SavedFeedCursor::CursorError,
    )
  end

  it "rejects oversized and malformed cursor values" do
    expect { described_class.decode("x" * (described_class::MAX_LENGTH + 1)) }.to raise_error(
      VideoHub::SavedFeedCursor::CursorError,
    )
    expect { described_class.decode("bad cursor") }.to raise_error(
      VideoHub::SavedFeedCursor::CursorError,
    )
  end

  it "rejects non-positive bookmark ids" do
    expect { described_class.encode(saved_at: saved_at, bookmark_id: 0) }.to raise_error(
      VideoHub::SavedFeedCursor::CursorError,
    )
  end
end
