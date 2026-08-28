# frozen_string_literal: true

module VideoHub
  class Video < ActiveRecord::Base
    PROVIDERS = %w[youtube tiktok instagram].freeze
    KINDS = %w[shorts landscape].freeze
    STATUSES = %w[pending published unavailable].freeze

    EXTERNAL_ID_MAX_LENGTH = 64
    CANONICAL_URL_MAX_LENGTH = 2048
    TITLE_MAX_LENGTH = 300
    DESCRIPTION_MAX_LENGTH = 2000
    THUMBNAIL_URL_MAX_LENGTH = 2048
    AUTHOR_MAX_LENGTH = 200

    belongs_to :user, optional: true
    belongs_to :topic, optional: true
    belongs_to :post, optional: true

    validates :user, presence: true, on: :create
    validates :provider, inclusion: { in: PROVIDERS }
    validates :external_id,
              presence: true,
              length: {
                maximum: EXTERNAL_ID_MAX_LENGTH,
              },
              uniqueness: {
                scope: :provider,
              }
    validates :canonical_url, presence: true, length: { maximum: CANONICAL_URL_MAX_LENGTH }
    validates :kind, inclusion: { in: KINDS }
    validates :status, inclusion: { in: STATUSES }
    validates :title, length: { maximum: TITLE_MAX_LENGTH }, allow_nil: true
    validates :description, length: { maximum: DESCRIPTION_MAX_LENGTH }, allow_nil: true
    validates :thumbnail_url, length: { maximum: THUMBNAIL_URL_MAX_LENGTH }, allow_nil: true
    validates :author_name, length: { maximum: AUTHOR_MAX_LENGTH }, allow_nil: true
    validates :duration_seconds,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
              },
              allow_nil: true
    validates :topic_id, uniqueness: true, allow_nil: true
    validates :post_id, uniqueness: true, allow_nil: true

    validate :mapping_pair_is_consistent
    validate :mapped_post_is_topic_root
    validate :published_mapping_is_complete

    private

    def mapping_pair_is_consistent
      return if topic_id.nil? == post_id.nil?

      errors.add(:base, :invalid)
    end

    def mapped_post_is_topic_root
      return if topic_id.nil? || post_id.nil?
      return if post&.topic_id == topic_id && post.post_number == 1

      errors.add(:post_id, :invalid)
    end

    def published_mapping_is_complete
      return unless status == "published"
      return if topic_id.present? && post_id.present? && published_at.present?

      errors.add(:status, :invalid)
    end
  end
end
