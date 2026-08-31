import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import VideoHubLanding from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-landing";
import VideoHubTrending from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-trending";

module("Integration | Component | VideoHubTrending", function (hooks) {
  setupRenderingTest(hooks);

  test("renders trending cards without discovery autoplay metric surfaces", async function (assert) {
    const model = {
      videos: [
        {
          id: 80,
          provider: "youtube",
          kind: "landscape",
          title: "Trending video",
          thumbnail_url: null,
          author_name: "Trending creator",
          watch_path: "/videos/80/trending-video",
        },
      ],
      providers: ["youtube"],
      pagination: { has_more: false, next_cursor: null },
    };
    let metricRequests = 0;

    pretender.post("/videos/80/metrics", () => {
      metricRequests += 1;
      return response({ recorded: true });
    });

    await render(<template><VideoHubTrending @model={{model}} /></template>);

    assert.dom(".video-hub-trending").exists();
    assert.dom(".video-hub-card").exists({ count: 1 });
    assert
      .dom(".video-hub-card")
      .hasAttribute("href", "/videos/80/trending-video");
    assert.dom(".video-hub-mobile-feed").doesNotExist();
    assert.dom(".video-hub-player__iframe").doesNotExist();
    assert.strictEqual(metricRequests, 0);
  });

  test("loads the next trending cursor page without duplicating videos", async function (assert) {
    const firstVideo = {
      id: 81,
      provider: "youtube",
      kind: "landscape",
      title: "First trending video",
      thumbnail_url: null,
      author_name: "First creator",
      watch_path: "/videos/81/first-trending-video",
    };
    const model = {
      videos: [firstVideo],
      providers: ["youtube"],
      pagination: { has_more: true, next_cursor: "trending-cursor-1" },
    };
    let requestCount = 0;

    pretender.get("/videos/trending/feed.json", (request) => {
      requestCount += 1;
      const cursor = new URL(
        request.url,
        window.location.origin
      ).searchParams.get("cursor");

      assert.strictEqual(cursor, "trending-cursor-1");

      return response({
        videos: [
          firstVideo,
          {
            id: 82,
            provider: "tiktok",
            kind: "shorts",
            title: "Second trending video",
            thumbnail_url: null,
            author_name: "Second creator",
            watch_path: "/videos/82/second-trending-video",
          },
        ],
        providers: ["youtube", "tiktok"],
        pagination: { has_more: false, next_cursor: null },
      });
    });

    await render(<template><VideoHubTrending @model={{model}} /></template>);
    await click(".video-hub-trending__pagination .btn");

    assert.strictEqual(requestCount, 1);
    assert.dom(".video-hub-card").exists({ count: 2 });
    assert
      .dom('.video-hub-card[href="/videos/81/first-trending-video"]')
      .exists({ count: 1 });
    assert
      .dom('.video-hub-card[href="/videos/82/second-trending-video"]')
      .exists({ count: 1 });
    assert.dom(".video-hub-trending__pagination").doesNotExist();
  });

  test("renders a bounded empty state", async function (assert) {
    const model = {
      videos: [],
      providers: [],
      pagination: { has_more: false, next_cursor: null },
    };

    await render(<template><VideoHubTrending @model={{model}} /></template>);

    assert.dom(".video-hub-trending__empty").exists();
    assert.dom(".video-hub-trending__pagination").doesNotExist();
  });
});

module(
  "Integration | Component | VideoHubLanding | trending shortcut | anonymous",
  function (hooks) {
    setupRenderingTest(hooks, { anonymous: true });

    test("links public viewers to trending videos", async function (assert) {
      const model = {
        videos: [],
        providers: [],
        pagination: { has_more: false, next_cursor: null },
      };

      await render(<template><VideoHubLanding @model={{model}} /></template>);

      assert
        .dom(".video-hub-page__trending-link")
        .hasAttribute("href", "/videos/trending")
        .hasText("Trending");
    });
  }
);
