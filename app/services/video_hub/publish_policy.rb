# frozen_string_literal: true

module VideoHub
  class PublishPolicy
    PROVIDER_SETTINGS = {
      "youtube" => :video_hub_youtube_enabled,
      "tiktok" => :video_hub_tiktok_enabled,
      "instagram" => :video_hub_instagram_enabled,
    }.freeze

    class AuthorizationError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    def self.authorize!(user:, provider:)
      new(user: user, provider: provider).authorize!
    end

    def self.authorize_base!(user:)
      new(user: user, provider: nil).authorize_base!
    end

    def self.authorize_provider!(provider:)
      new(user: nil, provider: provider).authorize_provider!
    end

    def initialize(user:, provider:)
      @user = user
      @provider = provider
    end

    def authorize!
      ensure_video_hub_enabled!
      ensure_logged_in!
      ensure_provider_enabled!
      ensure_trust_level!
      authorized_category
    end

    def authorize_base!
      ensure_video_hub_enabled!
      ensure_logged_in!
      ensure_trust_level!
      authorized_category
    end

    def authorize_provider!
      ensure_video_hub_enabled!
      ensure_provider_enabled!
      provider
    end

    private

    attr_reader :user, :provider

    def ensure_video_hub_enabled!
      raise AuthorizationError.new(:video_hub_disabled) unless SiteSetting.video_hub_enabled
    end

    def ensure_logged_in!
      raise AuthorizationError.new(:login_required) unless user
    end

    def ensure_provider_enabled!
      provider_setting = PROVIDER_SETTINGS[provider]
      raise AuthorizationError.new(:unsupported_provider) unless provider_setting
      unless SiteSetting.public_send(provider_setting)
        raise AuthorizationError.new(:provider_disabled)
      end
    end

    def ensure_trust_level!
      return if user.staff? || user.trust_level >= SiteSetting.video_hub_min_trust_level

      raise AuthorizationError.new(:insufficient_trust)
    end

    def authorized_category
      category = configured_category
      raise AuthorizationError.new(:category_not_configured) unless category

      guardian = Guardian.new(user)
      unless guardian.can_create_topic_on_category?(category)
        raise AuthorizationError.new(:not_allowed)
      end

      category
    end

    def configured_category
      category_id = SiteSetting.video_hub_category.to_i
      return if category_id <= 0

      Category.find_by(id: category_id)
    end
  end
end
