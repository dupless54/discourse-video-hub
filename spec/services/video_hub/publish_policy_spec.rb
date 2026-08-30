# frozen_string_literal: true

describe VideoHub::PublishPolicy do
  let(:category) { Fabricate(:category) }
  let(:user) { Fabricate(:user, trust_level: 1) }

  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_min_trust_level = 1
    SiteSetting.video_hub_category = category.id
    SiteSetting.video_hub_youtube_enabled = true
    SiteSetting.video_hub_tiktok_enabled = true
    SiteSetting.video_hub_instagram_enabled = false
  end

  it "returns only the configured category when core Guardian allows topic creation" do
    expect_guardian(user, category, allowed: true)

    expect(described_class.authorize!(user: user, provider: "youtube")).to eq(category)
  end

  it "supports a provider-independent authorization stage before any provider network work" do
    SiteSetting.video_hub_youtube_enabled = false
    SiteSetting.video_hub_tiktok_enabled = false
    expect_guardian(user, category, allowed: true)

    expect(described_class.authorize_base!(user: user)).to eq(category)
  end

  it "supports a provider-only authorization stage without repeating Guardian work" do
    Guardian.expects(:new).never

    expect(described_class.authorize_provider!(provider: "youtube")).to eq("youtube")
    expect do described_class.authorize_provider!(provider: "instagram") end.to raise_error(
      described_class::AuthorizationError,
    ) { |error| expect(error.code).to eq(:provider_disabled) }
  end

  it "fails closed when Video Hub is disabled" do
    SiteSetting.video_hub_enabled = false

    expect_authorization_error(user: user, provider: "youtube", code: :video_hub_disabled)
  end

  it "requires an authenticated user" do
    expect_authorization_error(user: nil, provider: "youtube", code: :login_required)
  end

  it "rejects unknown providers before authorization reaches Guardian" do
    Guardian.expects(:new).never

    expect_authorization_error(user: user, provider: "vimeo", code: :unsupported_provider)
  end

  it "rejects a supported provider when its site setting is disabled" do
    Guardian.expects(:new).never

    expect_authorization_error(user: user, provider: "instagram", code: :provider_disabled)
  end

  it "enforces the configured minimum trust level for members" do
    SiteSetting.video_hub_min_trust_level = 2
    Guardian.expects(:new).never

    expect_authorization_error(user: user, provider: "youtube", code: :insufficient_trust)
  end

  it "lets staff pass the Video Hub trust threshold while preserving the Guardian check" do
    staff = Fabricate(:admin)
    staff.update_column(:trust_level, 0)
    SiteSetting.video_hub_min_trust_level = 4
    expect_guardian(staff, category, allowed: true)

    expect(described_class.authorize!(user: staff, provider: "youtube")).to eq(category)
  end

  it "fails closed when staff has not configured a Video Hub category" do
    SiteSetting.video_hub_category = ""
    Guardian.expects(:new).never

    expect_authorization_error(user: user, provider: "youtube", code: :category_not_configured)
  end

  it "delegates final category permission to core Guardian" do
    expect_guardian(user, category, allowed: false)

    expect_authorization_error(user: user, provider: "youtube", code: :not_allowed)
  end

  def expect_guardian(user, category, allowed:)
    guardian = mock
    Guardian.expects(:new).with(user).returns(guardian)
    guardian.expects(:can_create_topic_on_category?).with(category).returns(allowed)
  end

  def expect_authorization_error(user:, provider:, code:)
    expect { described_class.authorize!(user: user, provider: provider) }.to raise_error(
      described_class::AuthorizationError,
    ) do |error|
      expect(error.code).to eq(code)
      expect(error.message).to eq(code.to_s)
    end
  end
end
