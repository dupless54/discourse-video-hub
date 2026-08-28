import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import VideoHubLanding from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-landing";

module("Integration | Component | VideoHubLanding", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the empty native landing state and enabled providers", async function (assert) {
    const model = {
      videos: [],
      providers: ["youtube", "tiktok"],
      pagination: { has_more: false, next_cursor: null },
    };

    await render(<template><VideoHubLanding @model={{model}} /></template>);

    assert.dom(".video-hub-page").exists();
    assert
      .dom(".video-hub-page__publish-link")
      .hasAttribute("href", "/videos/new")
      .hasText("Share video");
    assert.dom(".video-hub-page__empty").exists();
    assert.dom('[data-provider="youtube"]').hasText("YouTube");
    assert.dom('[data-provider="tiktok"]').hasText("TikTok");
    assert.dom('[data-provider="instagram"]').doesNotExist();
  });

  test("renders mixed discovery cards from the server payload without trusting markup", async function (assert) {
    const model = {
      videos: [
        {
          id: 10,
          provider: "youtube",
          kind: "landscape",
          title: "Literal <em>video</em>",
          thumbnail_url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
          author_name: "Example creator",
          watch_path: "/videos/10/literal-video",
        },
        {
          id: 11,
          provider: "tiktok",
          kind: "shorts",
          title: "Short video",
          thumbnail_url: null,
          author_name: null,
          watch_path: "/videos/11/short-video",
        },
      ],
      providers: ["youtube", "tiktok"],
      pagination: { has_more: false, next_cursor: null },
    };

    await render(<template><VideoHubLanding @model={{model}} /></template>);

    assert.dom(".video-hub-page__empty").doesNotExist();
    assert.dom(".video-hub-card").exists({ count: 2 });
    assert
      .dom('.video-hub-card[data-provider="youtube"]')
      .hasAttribute("data-kind", "landscape")
      .hasAttribute("href", "/videos/10/literal-video");
    assert
      .dom('.video-hub-card[data-provider="youtube"] img')
      .hasAttribute("src", "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
      .hasAttribute("alt", "");
    assert
      .dom('.video-hub-card[data-provider="youtube"] h2')
      .hasText("Literal <em>video</em>");
    assert
      .dom('.video-hub-card[data-provider="youtube"] h2 em')
      .doesNotExist("does not render server text as HTML");
    assert
      .dom('.video-hub-card[data-provider="youtube"] .video-hub-card__author')
      .hasText("Example creator");
    assert
      .dom('.video-hub-card[data-provider="tiktok"]')
      .hasAttribute("data-kind", "shorts")
      .hasAttribute("href", "/videos/11/short-video");
    assert
      .dom(
        '.video-hub-card[data-provider="tiktok"] .video-hub-card__placeholder'
      )
      .hasText("TikTok");
    assert
      .dom('.video-hub-card[data-provider="tiktok"] .video-hub-card__author')
      .doesNotExist();
  });

  test("loads the next server cursor page without duplicating existing cards", async function (assert) {
    const model = {
      videos: [
        {
          id: 10,
          provider: "youtube",
          kind: "landscape",
          title: "First video",
          thumbnail_url: null,
          author_name: null,
          watch_path: "/videos/10/first-video",
        },
      ],
      providers: ["youtube", "tiktok"],
      pagination: { has_more: true, next_cursor: "cursor-1" },
    };
    let requestCount = 0;

    pretender.get("/videos/feed.json", (request) => {
      requestCount += 1;
      const cursor = new URL(
        request.url,
        window.location.origin
      ).searchParams.get("cursor");
      assert.strictEqual(cursor, "cursor-1", "uses only the server cursor");

      return response({
        videos: [
          model.videos[0],
          {
            id: 12,
            provider: "tiktok",
            kind: "shorts",
            title: "Next video",
            thumbnail_url: null,
            author_name: "Next creator",
            watch_path: "/videos/12/next-video",
          },
        ],
        pagination: { has_more: false, next_cursor: null },
      });
    });

    await render(<template><VideoHubLanding @model={{model}} /></template>);

    assert.dom(".video-hub-page__pagination .btn").exists();
    await click(".video-hub-page__pagination .btn");

    assert.strictEqual(requestCount, 1);
    assert.dom(".video-hub-card").exists({ count: 2 });
    assert
      .dom('.video-hub-card[href="/videos/12/next-video"]')
      .exists("appends the new canonical card");
    assert
      .dom('.video-hub-card[href="/videos/10/first-video"]')
      .exists({ count: 1 }, "does not duplicate an existing video id");
    assert
      .dom(".video-hub-page__pagination")
      .doesNotExist(
        "hides pagination when the server says the feed is exhausted"
      );
  });

  test("keeps the current cursor and cards when loading the next page fails", async function (assert) {
    const model = {
      videos: [
        {
          id: 20,
          provider: "youtube",
          kind: "landscape",
          title: "Stable video",
          thumbnail_url: null,
          author_name: null,
          watch_path: "/videos/20/stable-video",
        },
      ],
      providers: ["youtube"],
      pagination: { has_more: true, next_cursor: "retry-cursor" },
    };
    let requestCount = 0;

    pretender.get("/videos/feed.json", (request) => {
      requestCount += 1;
      const cursor = new URL(
        request.url,
        window.location.origin
      ).searchParams.get("cursor");
      assert.strictEqual(cursor, "retry-cursor");
      return response(500, { errors: ["Temporary failure"] });
    });

    await render(<template><VideoHubLanding @model={{model}} /></template>);
    await click(".video-hub-page__pagination .btn");

    assert.strictEqual(requestCount, 1);
    assert.dom(".video-hub-card").exists({ count: 1 });
    assert
      .dom('.video-hub-card[href="/videos/20/stable-video"]')
      .exists("keeps already rendered cards");
    assert
      .dom(".video-hub-page__pagination .btn")
      .exists("keeps the same cursor available for retry");
  });
});
