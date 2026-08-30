# frozen_string_literal: true

module VideoHub
  class PublishVideo
    RATE_LIMIT_MAX = 10
    RATE_LIMIT_WINDOW = 1.minute
    CAPTION_MAX_LENGTH = 2000
    LOCK_PREFIX = "video_hub_publish"

    VIDEO_METADATA_KEYS = %i[
      provider
      external_id
      canonical_url
      kind
      title
      description
      thumbnail_url
      duration_seconds
      author_name
    ].freeze

    class PublishError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    def self.publish(user:, url:, caption: nil)
      new(user: user, url: url, caption: caption).publish
    end

    def initialize(user:, url:, caption:)
      @user = user
      @url = url
      @caption = caption
    end

    def publish
      category = PublishPolicy.authorize_base!(user: user)
      normalized_caption = normalize_caption
      enforce_rate_limit!

      resolved = ProviderUrlResolver.resolve(url)
      PublishPolicy.authorize_provider!(provider: resolved.provider)

      existing = find_existing(resolved)
      return visible_existing!(existing) if existing&.topic_id

      metadata = ProviderMetadataFetcher.fetch(resolved.canonical_url)
      validate_metadata_identity!(metadata, resolved)

      post_creator = nil
      newly_published = false
      video =
        DistributedMutex.synchronize(lock_key(resolved)) do
          locked_existing = find_existing(resolved)
          next visible_existing!(locked_existing) if locked_existing&.topic_id

          Video.transaction do
            video = locked_existing || Video.new
            video.assign_attributes(video_attributes(metadata))
            video.user ||= user

            post_creator =
              PostCreator.new(user, post_options(category, metadata, normalized_caption))
            post = post_creator.create!
            published_at = Time.zone.now

            video.assign_attributes(
              topic: post.topic,
              post: post,
              status: "published",
              published_at: published_at,
              metadata_refreshed_at: published_at,
            )
            video.save!
            newly_published = true
            video
          end
        end

      finalize_post_creation(post_creator)
      enqueue_metadata_refresh(video) if newly_published
      video
    rescue PublishPolicy::AuthorizationError,
           ProviderUrlResolver::ResolveError,
           ProviderMetadataFetcher::MetadataError => error
      raise PublishError.new(error.code)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved
      raise PublishError.new(:publish_failed)
    end

    private

    attr_reader :user, :url, :caption

    def normalize_caption
      return if caption.nil?
      raise PublishError.new(:invalid_caption) unless caption.is_a?(String)
      raise PublishError.new(:invalid_caption) if caption.match?(/\u0000/)

      normalized = caption.strip
      return if normalized.empty?
      raise PublishError.new(:caption_too_long) if normalized.length > CAPTION_MAX_LENGTH

      normalized
    end

    def enforce_rate_limit!
      RateLimiter.new(user, "video_hub_publish", RATE_LIMIT_MAX, RATE_LIMIT_WINDOW).performed!
    end

    def find_existing(resolved)
      Video.find_by(provider: resolved.provider, external_id: resolved.external_id)
    end

    def visible_existing!(video)
      raise Discourse::NotFound unless Guardian.new(user).can_see?(video.topic)

      video
    end

    def validate_metadata_identity!(metadata, resolved)
      valid =
        metadata.is_a?(Hash) && metadata[:provider] == resolved.provider &&
          metadata[:external_id] == resolved.external_id &&
          metadata[:canonical_url] == resolved.canonical_url
      raise PublishError.new(:metadata_identity_mismatch) unless valid
    end

    def video_attributes(metadata)
      metadata.slice(*VIDEO_METADATA_KEYS)
    end

    def post_options(category, metadata, normalized_caption)
      {
        title: topic_title(metadata),
        raw: post_raw(metadata.fetch(:canonical_url), normalized_caption),
        category: category.id,
        guardian: Guardian.new(user),
        skip_jobs: true,
        skip_events: true,
      }
    end

    def topic_title(metadata)
      provider_label = metadata.fetch(:provider).capitalize
      fallback = "#{provider_label} video #{metadata.fetch(:external_id)}"
      title = metadata[:title].presence || fallback
      max_length = SiteSetting.max_topic_title_length
      min_length = SiteSetting.min_topic_title_length

      title = title[0, max_length]
      if title.length < min_length
        title = "#{title} — #{provider_label} video"
        title = title[0, max_length]
      end

      title
    end

    def post_raw(canonical_url, normalized_caption)
      return canonical_url unless normalized_caption

      "#{normalized_caption}\n\n#{canonical_url}"
    end

    def lock_key(resolved)
      "#{LOCK_PREFIX}:#{resolved.provider}:#{resolved.external_id}"
    end

    def finalize_post_creation(post_creator)
      return unless post_creator

      post_creator.trigger_after_events
      post_creator.enqueue_jobs
    end

    def enqueue_metadata_refresh(video)
      Jobs.enqueue_in(
        VideoHub::RefreshVideoMetadata::STALE_AFTER,
        Jobs::VideoHub::RefreshVideoMetadata,
        video_id: video.id,
      )
    rescue StandardError => error
      Rails.logger.warn(
        "[VideoHub] metadata refresh enqueue failed video_id=#{video.id} error=#{error.class.name}",
      )
    end
  end
end
