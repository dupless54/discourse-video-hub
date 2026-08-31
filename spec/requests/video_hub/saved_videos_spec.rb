# frozen_string_literal: true

describe "Video Hub saved videos" do
  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
  end

  let(:owner) { Fabricate(:user) }
  let(:viewer) { Fabricate(:user) }
  let(:video) { create_video(owner: owner) }

  describe "POST /videos/:id/save" do
    it "requires login before creating any bookmark" do
      post "/videos/#{video.id}/save.json"

      expect(response.status).to eq(403)
      expect(Bookmark.where(bookmarkable_id: video.post_id).count).to eq(0)
    end

    it "creates one core bookmark and returns an idempotent saved contract" do
      sign_in(viewer)

      post "/videos/#{video.id}/save.json"
      first_body = response.parsed_body
      first_bookmark_id = first_body.fetch("bookmark_id")

      expect(response.status).to eq(200)
      expect(first_body).to eq({ "saved" => true, "bookmark_id" => first_bookmark_id })

      post "/videos/#{video.id}/save.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq({ "saved" => true, "bookmark_id" => first_bookmark_id })
      expect(
        Bookmark.where(
          user_id: viewer.id,
          bookmarkable_type: Post.polymorphic_name,
          bookmarkable_id: video.post_id,
        ).count,
      ).to eq(1)
    end

    it "returns not found for a video hidden from the authenticated viewer" do
      group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: group)
      private_video = create_video(owner: owner, category: private_category)
      sign_in(viewer)

      post "/videos/#{private_video.id}/save.json"

      expect(response.status).to eq(404)
      expect(Bookmark.where(user_id: viewer.id).count).to eq(0)
    end

    it "returns not found before saving when Video Hub is disabled" do
      sign_in(viewer)
      SiteSetting.video_hub_enabled = false

      post "/videos/#{video.id}/save.json"

      expect(response.status).to eq(404)
      expect(Bookmark.where(user_id: viewer.id).count).to eq(0)
    end
  end

  describe "DELETE /videos/:id/save" do
    it "requires login before deleting any bookmark" do
      bookmark = VideoHub::SavedVideo.save(user: viewer, video_id: video.id)

      delete "/videos/#{video.id}/save.json"

      expect(response.status).to eq(403)
      expect(Bookmark.exists?(bookmark.bookmark_id)).to eq(true)
    end

    it "removes only the authenticated viewer's bookmark and is idempotent" do
      other_viewer = Fabricate(:user)
      viewer_bookmark = VideoHub::SavedVideo.save(user: viewer, video_id: video.id)
      other_bookmark = VideoHub::SavedVideo.save(user: other_viewer, video_id: video.id)
      sign_in(viewer)

      delete "/videos/#{video.id}/save.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq({ "saved" => false, "bookmark_id" => nil })
      expect(Bookmark.exists?(viewer_bookmark.bookmark_id)).to eq(false)
      expect(Bookmark.exists?(other_bookmark.bookmark_id)).to eq(true)

      delete "/videos/#{video.id}/save.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq({ "saved" => false, "bookmark_id" => nil })
    end
  end

  def create_video(owner:, category: nil)
    @video_sequence = @video_sequence.to_i + 1
    topic = Fabricate(:topic, user: owner, category: category)
    post = Fabricate(:post, topic: topic, user: owner)

    VideoHub::Video.create!(
      user: owner,
      topic: topic,
      post: post,
      provider: "youtube",
      external_id: "saved-request-video-#{@video_sequence}",
      canonical_url: "https://www.youtube.com/watch?v=saved-request-video-#{@video_sequence}",
      kind: "landscape",
      title: "Saved request video #{@video_sequence}",
      status: "published",
      published_at: Time.zone.now,
    )
  end
end
