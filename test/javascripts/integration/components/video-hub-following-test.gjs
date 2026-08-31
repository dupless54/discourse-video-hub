import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import VideoHubFollowing from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-following";
import VideoHubLanding from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-landing";

module("Integration | Component | VideoHubFollowing", function (hooks) {
  setupRenderingTest(hooks);

  test("renders followed-user cards without discovery metric surfaces", async function (assert) {
    const model = {
      videos: [
        {
          id: 90,
          provider: "youtube",
          kind: "landscape",
          title: "Following video",
          thumbnail_url: null,
          author_name: "Followed creator",
          watch_path: "/videos/90/following-video",
        },
      ],
      pagination: { has_more: false, next_cursor: null },
    };
    let metricRequests = 0;

    pretender.post("/videos/90/metrics", () => {
      metricRequests += 1;
      return response({ recorded: true });
    });

    await render(<template><VideoHubFollowing @model={{model}} /></template>);

    assert.dom(".video-hub-following").exists();
    assert.dom(".video-hub-card").exists({ count: 1 });
    assert
      .dom(".video-hub-card")
      .hasAttribute("href", "/videos/90/following-video");
    assert.dom(".video-hub-mobile-feed").doesNotExist();
    assert.dom(".video-hub-player__iframe").doesNotExist();
    assert.strictEqual(metricRequests, 0);
  });

  test("loads the next following cursor page without duplicating videos", async function (assert) {
    const firstVideo = {
      id: 91,
      provider: "youtube",
      kind: "landscape",
      title: "First following video",
      thumbnail_url: null,
      author_name: "First followed creator",
      watch_path: "/videos/91/first-following-video",
    };
    const model = {
      videos: [firstVideo],
      pagination: { has_more: true, next_cursor: "following-cursor-1" },
    };
    let requestCount = 0;

    pretender.get("/videos/following/feed.json", (request) => {
      requestCount += 1;
      const cursor = new URL(
        request.url,
        window.location.origin
      ).searchParams.get("cursor");

      assert.strictEqual(cursor, "following-cursor-1");

      return response({
        videos: [
          firstVideo,
          {
            id: 92,
            provider: "tiktok",
            kind: "shorts",
            title: "Second following video",
            thumbnail_url: null,
            author_name: "Second followed creator",
            watch_path: "/videos/92/second-following-video",
          },
        ],
        pagination: { has_more: false, next_cursor: null },
      });
    });

    await render(<template><VideoHubFollowing @model={{model}} /></template>);
    await click(".video-hub-following__pagination .btn");

    assert.strictEqual(requestCount, 1);
    assert.dom(".video-hub-card").exists({ count: 2 });
    assert
      .dom('.video-hub-card[href="/videos/91/first-following-video"]')
      .exists({ count: 1 });
    assert
      .dom('.video-hub-card[href="/videos/92/second-following-video"]')
      .exists({ count: 1 });
    assert.dom(".video-hub-following__pagination").doesNotExist();
  });

  test("renders the no-content state", async function (assert) {
    const model = {
      videos: [],
      pagination: { has_more: false, next_cursor: null },
    };

    await render(<template><VideoHubFollowing @model={{model}} /></template>);

    assert.dom(".video-hub-following__empty").exists();
    assert.dom(".video-hub-following__pagination").doesNotExist();
  });
});

const landingModel = {
  videos: [],
  providers: [],
  pagination: { has_more: false, next_cursor: null },
};

module(
  "Integration | Component | VideoHubLanding | following shortcut | anonymous",
  function (hooks) {
    setupRenderingTest(hooks, { anonymous: true });

    test("does not expose the private following shortcut", async function (assert) {
      await render(
        <template><VideoHubLanding @model={{landingModel}} /></template>
      );

      assert.dom(".video-hub-page__following-link").doesNotExist();
    });
  }
);

module(
  "Integration | Component | VideoHubLanding | following shortcut | authenticated",
  function (hooks) {
    setupRenderingTest(hooks);

    test("links authenticated viewers to their following feed", async function (assert) {
      await render(
        <template><VideoHubLanding @model={{landingModel}} /></template>
      );

      assert
        .dom(".video-hub-page__following-link")
        .hasAttribute("href", "/videos/following")
        .hasText("Following");
    });
  }
);
