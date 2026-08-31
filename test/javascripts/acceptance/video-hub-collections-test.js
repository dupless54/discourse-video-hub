import { currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Video Hub collections management", function (needs) {
  needs.user();

  test("loads the authenticated collections management route", async function (assert) {
    let requests = 0;

    pretender.get("/videos/collections.json", () => {
      requests += 1;
      return response({
        collections: [
          {
            id: 42,
            collection_type: "playlist",
            title: "Favorites",
            description: "My favorite videos",
            position: 0,
            visible: true,
            items: [
              {
                id: 400,
                video_id: 91,
                position: 0,
                video: {
                  id: 91,
                  provider: "youtube",
                  kind: "landscape",
                  title: "Managed video",
                  thumbnail_url: null,
                  author_name: "Route creator",
                  watch_path: "/videos/91/managed-video",
                },
              },
            ],
          },
        ],
      });
    });

    await visit("/videos/collections");

    assert.strictEqual(requests, 1);
    assert.strictEqual(currentURL(), "/videos/collections");
    assert.dom(".video-hub-collections").exists();
    assert.dom('[data-collection-id="42"]').exists();
    assert
      .dom('.video-hub-collections__public-link[href="/videos/collections/42"]')
      .exists();
    assert
      .dom('.video-hub-collections__item-preview[href="/videos/91/managed-video"]')
      .exists();
  });
});

acceptance("Video Hub collections management | anonymous", function () {
  test("opens the login flow without requesting the private collections API", async function (assert) {
    let requests = 0;

    pretender.get("/videos/collections.json", () => {
      requests += 1;
      return response({ collections: [] });
    });

    await visit("/videos/collections");

    assert.strictEqual(requests, 0);
  });
});
