import { currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Video Hub following videos", function (needs) {
  needs.user();

  test("loads the authenticated following feed route", async function (assert) {
    let requests = 0;

    pretender.get("/videos/following/feed.json", () => {
      requests += 1;
      return response({
        videos: [
          {
            id: 90,
            provider: "youtube",
            kind: "landscape",
            title: "Following route video",
            thumbnail_url: null,
            author_name: "Followed creator",
            watch_path: "/videos/90/following-route-video",
          },
        ],
        pagination: { has_more: false, next_cursor: null },
      });
    });

    await visit("/videos/following");

    assert.strictEqual(requests, 1);
    assert.strictEqual(currentURL(), "/videos/following");
    assert.dom(".video-hub-following").exists();
    assert
      .dom('.video-hub-card[href="/videos/90/following-route-video"]')
      .exists();
  });
});

acceptance("Video Hub following videos | anonymous", function () {
  test("opens the login flow without requesting the private following feed", async function (assert) {
    let requests = 0;

    pretender.get("/videos/following/feed.json", () => {
      requests += 1;
      return response({
        videos: [],
        pagination: { has_more: false, next_cursor: null },
      });
    });

    await visit("/videos/following");

    assert.strictEqual(requests, 0);
  });
});
