# frozen_string_literal: true

module VideoHub
  class FollowSource
    class SourceError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    def self.following_user_ids(user:)
      raise SourceError.new(:login_required) unless user
      raise SourceError.new(:follow_unavailable) unless available?(user: user)

      user.following.select(:id)
    end

    def self.available?(user:)
      setting_enabled? && user.respond_to?(:following)
    end

    def self.setting_enabled?
      SiteSetting.respond_to?(:discourse_follow_enabled) && SiteSetting.discourse_follow_enabled
    rescue NoMethodError
      false
    end
  end
end
