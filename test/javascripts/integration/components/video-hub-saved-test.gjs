import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import VideoHubSaved from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-saved";

module("Integration | Component | VideoHubSaved", function (hooks) {
  setupRenderingTest(hooks);

  test("renders saved cards and removes a video through the core-backed mutation", async function (assert) {
    const model = {
      videos: [
        {
          id: 42,
          provider: "youtube",
          kind: "landscape",
          title: "Saved video",
          thumbnail_url: null,
          author_name: "Saved creator",
          watch_path: "/videos/42/saved-video",
          saved: true,
          bookmark_id: 9001,
        },
      ],
      pagination: { has_more: false, next_cursor: null },
    };
    let removeRequests = 0;

    pretender.delete("/videos/42/save", () => {
      removeRequests += 1;
      return response({ saved: false, bookmark_id: null });
    });

    await render(<template><VideoHubSaved @model={{model}} /></template>);

    assert.dom(".video-hub-saved").exists();
    assert.dom(".video-hub-card").exists({ count: 1 });
    assert
      .dom(".video-hub-card")
      .hasAttribute("href", "/videos/42/saved-video");
    assert.dom(".video-hub-saved__remove").hasText("Remove from saved");

    await click(".video-hub-saved__remove");

    assert.strictEqual(removeRequests, 1);
    assert.dom(".video-hub-card").doesNotExist();
    assert.dom(".video-hub-saved__empty").exists();
  });

  test("loads the next saved cursor page without duplicating existing videos", async function (assert) {
    const firstVideo = {
      id: 50,
      provider: "youtube",
      kind: "landscape",
      title: "First saved video",
      thumbnail_url: null,
      author_name: null,
      watch_path: "/videos/50/first-saved-video",
      saved: true,
      bookmark_id: 500,
    };
    const model = {
      videos: [firstVideo],
      pagination: { has_more: true, next_cursor: "saved-cursor-1" },
    };
    let requestCount = 0;

    pretender.get("/videos/saved/feed.json", (request) => {
      requestCount += 1;
      const cursor = new URL(
        request.url,
        window.location.origin
      ).searchParams.get("cursor");

      assert.strictEqual(cursor, "saved-cursor-1");

      return response({
        videos: [
          firstVideo,
          {
            id: 51,
            provider: "tiktok",
            kind: "shorts",
            title: "Second saved video",
            thumbnail_url: null,
            author_name: "Second creator",
            watch_path: "/videos/51/second-saved-video",
            saved: true,
            bookmark_id: 501,
          },
        ],
        pagination: { has_more: false, next_cursor: null },
      });
    });

    await render(<template><VideoHubSaved @model={{model}} /></template>);
    await click(".video-hub-saved__pagination .btn");

    assert.strictEqual(requestCount, 1);
    assert.dom(".video-hub-card").exists({ count: 2 });
    assert
      .dom('.video-hub-card[href="/videos/50/first-saved-video"]')
      .exists({ count: 1 });
    assert
      .dom('.video-hub-card[href="/videos/51/second-saved-video"]')
      .exists({ count: 1 });
    assert.dom(".video-hub-saved__pagination").doesNotExist();
  });

  test("renders the saved empty state without discovery autoplay surfaces", async function (assert) {
    const model = {
      videos: [],
      pagination: { has_more: false, next_cursor: null },
    };

    await render(<template><VideoHubSaved @model={{model}} /></template>);

    assert.dom(".video-hub-saved__empty").exists();
    assert.dom(".video-hub-mobile-feed").doesNotExist();
    assert.dom(".video-hub-player__iframe").doesNotExist();
  });
});
