import { currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Video Hub trending videos | anonymous", function () {
  test("loads the public trending feed route", async function (assert) {
    let requests = 0;

    pretender.get("/videos/trending/feed.json", () => {
      requests += 1;
      return response({
        videos: [
          {
            id: 80,
            provider: "youtube",
            kind: "landscape",
            title: "Trending route video",
            thumbnail_url: null,
            author_name: "Trending creator",
            watch_path: "/videos/80/trending-route-video",
          },
        ],
        providers: ["youtube"],
        pagination: { has_more: false, next_cursor: null },
      });
    });

    await visit("/videos/trending");

    assert.strictEqual(requests, 1);
    assert.strictEqual(currentURL(), "/videos/trending");
    assert.dom(".video-hub-trending").exists();
    assert
      .dom('.video-hub-card[href="/videos/80/trending-route-video"]')
      .exists();
  });
});
