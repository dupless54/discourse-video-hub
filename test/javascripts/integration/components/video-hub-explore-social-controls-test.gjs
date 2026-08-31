import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";
import VideoHubMobileFeedItem from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-mobile-feed-item";

function video() {
  return {
    id: 42,
    provider: "youtube",
    external_id: "dQw4w9WgXcQ",
    kind: "shorts",
    title: "Interactive explore video",
    thumbnail_url: null,
    author_name: "Explore creator",
    topic_id: 100,
    post_id: 101,
    watch_path: "/videos/42/interactive-explore-video",
  };
}

function topicPayload({ liked = false, likeCount = 3 } = {}) {
  return {
    id: 100,
    post_stream: {
      posts: [
        {
          id: 101,
          post_number: 1,
          username: "video-owner",
          cooked: "<p>Video root post</p>",
          actions_summary: [
            {
              id: 2,
              count: likeCount,
              acted: liked,
              can_act: !liked,
              can_undo: liked,
            },
          ],
        },
      ],
    },
  };
}

module(
  "Integration | Component | VideoHubMobileFeedItem | immersive social controls",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      stubIntersectionObserver();
      this.video = video();
      this.noop = () => {};
    });

    test("uses the canonical root post for likes and opens the canonical discussion drawer", async function (assert) {
      let topic = topicPayload();
      let likeRequests = 0;
      let topicRequests = 0;

      pretender.get("/t/100.json", () => {
        topicRequests += 1;
        return response(topic);
      });
      pretender.post("/post_actions", (request) => {
        likeRequests += 1;
        const params = new URLSearchParams(request.requestBody);

        assert.strictEqual(params.get("id"), "101");
        assert.strictEqual(params.get("post_action_type_id"), "2");
        topic = topicPayload({ liked: true, likeCount: 4 });
        return response({ result: [] });
      });
      pretender.get("/posts/101/replies.json", () =>
        response([
          {
            id: 102,
            post_number: 2,
            username: "alice",
            cooked: "<p>Explore comment</p>",
            reply_count: 0,
            actions_summary: [],
          },
        ])
      );

      await render(
        <template>
          <VideoHubMobileFeedItem
            @video={{this.video}}
            @index={{0}}
            @total={{1}}
            @activeVideoId={{42}}
            @onActivate={{this.noop}}
            @onVisibilityChange={{this.noop}}
            @onNavigate={{this.noop}}
            @immersive={{true}}
          />
        </template>
      );

      assert.dom(".video-hub-mobile-feed__action--like").exists();
      assert.dom(".video-hub-mobile-feed__action--comments").exists();
      assert.dom(".video-hub-explore-comments").doesNotExist();

      await click(".video-hub-mobile-feed__action--like");
      await settled();

      assert.strictEqual(likeRequests, 1);
      assert.strictEqual(
        topicRequests,
        2,
        "loads then refreshes the canonical topic"
      );
      assert.dom(".video-hub-mobile-feed__action--like").hasClass("is-active");

      await click(".video-hub-mobile-feed__action--comments");
      await settled();

      assert.dom(".video-hub-explore-comments").exists();
      assert.dom(".video-hub-discussion").exists();
      assert.dom('[data-post-id="102"]').hasText("alice Explore comment Reply");

      await click(".video-hub-explore-comments__close");
      assert.dom(".video-hub-explore-comments").doesNotExist();
    });
  }
);
