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

    def initialize(user:, provider:)
      @user = user
      @provider = provider
    end

    def authorize!
      raise AuthorizationError.new(:video_hub_disabled) unless SiteSetting.video_hub_enabled
      raise AuthorizationError.new(:login_required) unless user

      provider_setting = PROVIDER_SETTINGS[provider]
      raise AuthorizationError.new(:unsupported_provider) unless provider_setting
      raise AuthorizationError.new(:provider_disabled) unless SiteSetting.public_send(provider_setting)

      unless user.staff? || user.trust_level >= SiteSetting.video_hub_min_trust_level
        raise AuthorizationError.new(:insufficient_trust)
      end

      category = configured_category
      raise AuthorizationError.new(:category_not_configured) unless category

      guardian = Guardian.new(user)
      unless guardian.can_create_topic_on_category?(category)
        raise AuthorizationError.new(:not_allowed)
      end

      category
    end

    private

    attr_reader :user, :provider

    def configured_category
      category_id = SiteSetting.video_hub_category.to_i
      return if category_id <= 0

      Category.find_by(id: category_id)
    end
  end
end
