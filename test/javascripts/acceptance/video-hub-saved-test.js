import { currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Video Hub saved videos", function (needs) {
  needs.user();

  test("loads the authenticated saved feed route", async function (assert) {
    let requests = 0;

    pretender.get("/videos/saved/feed.json", () => {
      requests += 1;
      return response({
        videos: [
          {
            id: 70,
            provider: "youtube",
            kind: "landscape",
            title: "Saved route video",
            thumbnail_url: null,
            author_name: "Route creator",
            watch_path: "/videos/70/saved-route-video",
            saved: true,
            bookmark_id: 700,
          },
        ],
        pagination: { has_more: false, next_cursor: null },
      });
    });

    await visit("/videos/saved");

    assert.strictEqual(requests, 1);
    assert.strictEqual(currentURL(), "/videos/saved");
    assert.dom(".video-hub-saved").exists();
    assert
      .dom('.video-hub-card[href="/videos/70/saved-route-video"]')
      .exists();
  });
});

acceptance("Video Hub saved videos | anonymous", function () {
  test(
    "opens the login flow without requesting the private saved feed",
    async function (assert) {
      let requests = 0;

      pretender.get("/videos/saved/feed.json", () => {
        requests += 1;
        return response({
          videos: [],
          pagination: { has_more: false, next_cursor: null },
        });
      });

      await visit("/videos/saved");

      assert.strictEqual(requests, 0);
    }
  );
});
