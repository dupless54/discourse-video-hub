# frozen_string_literal: true

describe VideoHub::FollowSource do
  let(:viewer) { Fabricate(:user) }
  let(:followed) { Fabricate(:user) }

  it "requires an authenticated user" do
    expect { described_class.following_user_ids(user: nil) }.to raise_error(
      described_class::SourceError,
    ) { |error| expect(error.code).to eq(:login_required) }
  end

  it "fails closed when the official follow integration is unavailable" do
    described_class.stubs(:setting_enabled?).returns(false)

    expect { described_class.following_user_ids(user: viewer) }.to raise_error(
      described_class::SourceError,
    ) { |error| expect(error.code).to eq(:follow_unavailable) }
  end

  it "uses the official User#following association as a relation source" do
    followed_scope = User.where(id: followed.id)
    viewer.define_singleton_method(:following) { followed_scope }
    described_class.stubs(:setting_enabled?).returns(true)

    result = described_class.following_user_ids(user: viewer)

    expect(result).to be_a(ActiveRecord::Relation)
    expect(result.pluck(:id)).to eq([followed.id])
  end
end
