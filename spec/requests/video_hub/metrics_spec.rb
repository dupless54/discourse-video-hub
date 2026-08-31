# frozen_string_literal: true

describe VideoHub::VideosController do
  before do
    SiteSetting.video_hub_enabled = true
    SiteSetting.video_hub_youtube_enabled = true
  end

  let(:user) { Fabricate(:user) }

  describe "POST /videos/:id/metrics" do
    it "requires login before invoking the metric recorder" do
      VideoHub::RecordMetric.expects(:record).never

      post "/videos/1/metrics", params: { event: "impression" }

      expect(response.status).to eq(403)
    end

    it "requires an event before invoking the metric recorder" do
      sign_in(user)
      VideoHub::RecordMetric.expects(:record).never

      post "/videos/1/metrics"

      expect(response.status).to eq(400)
    end

    it "passes only the authenticated viewer, route video id, and event to the recorder" do
      sign_in(user)
      VideoHub::RecordMetric
        .expects(:record)
        .with(user: user, video_id: "42", event: "impression")
        .returns(:recorded)

      post "/videos/42/metrics",
           params: {
             event: "impression",
             user_id: 999_999,
             impressions: 50_000,
             qualified_views: 50_000,
           }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq({ "recorded" => true })
    end

    it "does not expose duplicate or ignored reasons" do
      sign_in(user)
      VideoHub::RecordMetric.expects(:record).returns(:duplicate)

      post "/videos/42/metrics", params: { event: "impression" }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq({ "recorded" => false })
    end

    it "maps invalid metric events to a stable unprocessable response" do
      sign_in(user)
      VideoHub::RecordMetric.expects(:record).raises(
        VideoHub::RecordMetric::MetricError.new(:invalid_event),
      )

      post "/videos/42/metrics", params: { event: "completion" }

      expect(response.status).to eq(422)
      expect(response.parsed_body).to eq({ "error" => { "code" => "invalid_event" } })
    end

    it "returns not found before recording when Video Hub is disabled" do
      sign_in(user)
      SiteSetting.video_hub_enabled = false
      VideoHub::RecordMetric.expects(:record).never

      post "/videos/42/metrics", params: { event: "impression" }

      expect(response.status).to eq(404)
    end
  end
end
