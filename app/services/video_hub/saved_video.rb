# frozen_string_literal: true

module VideoHub
  class SavedVideo
    Result = Struct.new(:saved, :bookmark_id, keyword_init: true)

    class SaveError < StandardError
      attr_reader :code

      def initialize(code)
        @code = code
        super(code.to_s)
      end
    end

    def self.save(user:, video_id:)
      new(user:, video_id:).save
    end

    def self.unsave(user:, video_id:)
      new(user:, video_id:).unsave
    end

    def initialize(user:, video_id:)
      @user = user
      @video_id = video_id
    end

    def save
      video = visible_video
      bookmark = bookmark_for(video)
      return result(saved: true, bookmark: bookmark) if bookmark

      RateLimiter.new(
        user,
        "create_bookmark",
        SiteSetting.max_bookmarks_per_day,
        1.day.to_i,
      ).performed!

      manager = BookmarkManager.new(user)
      bookmark =
        manager.create_for(bookmarkable_id: video.post_id, bookmarkable_type: Post.polymorphic_name)

      if manager.errors.any? || !bookmark.is_a?(Bookmark)
        bookmark = bookmark_for(video)
        return result(saved: true, bookmark: bookmark) if bookmark

        raise SaveError.new(:save_failed)
      end

      result(saved: true, bookmark: bookmark)
    end

    def unsave
      video = visible_video
      bookmark = bookmark_for(video)
      return result(saved: false) unless bookmark

      BookmarkManager.new(user).destroy(bookmark.id)
      result(saved: false)
    end

    private

    attr_reader :user, :video_id

    def visible_video
      WatchQuery.fetch(user: user, id: video_id).video
    end

    def bookmark_for(video)
      Bookmark.find_by(
        user_id: user.id,
        bookmarkable_type: Post.polymorphic_name,
        bookmarkable_id: video.post_id,
      )
    end

    def result(saved:, bookmark: nil)
      Result.new(saved: saved, bookmark_id: bookmark&.id).freeze
    end
  end
end
