import { currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Video Hub public collection | anonymous", function () {
  test("loads the public collection route from the read API", async function (assert) {
    let requests = 0;

    pretender.get("/videos/collections/42.json", () => {
      requests += 1;
      return response({
        collection: {
          id: 42,
          collection_type: "playlist",
          title: "Weekend picks",
          description: "A public playlist",
          owner: {
            id: 7,
            username: "collection-owner",
            name: "Collection Owner",
          },
          items: [
            {
              position: 0,
              video: {
                id: 90,
                provider: "youtube",
                kind: "landscape",
                title: "Collection route video",
                thumbnail_url: null,
                author_name: "Collection creator",
                watch_path: "/videos/90/collection-route-video",
              },
            },
          ],
        },
      });
    });

    await visit("/videos/collections/42");

    assert.strictEqual(requests, 1);
    assert.strictEqual(currentURL(), "/videos/collections/42");
    assert.dom(".video-hub-collection").exists();
    assert.dom(".video-hub-collection h1").hasText("Weekend picks");
    assert
      .dom('.video-hub-card[href="/videos/90/collection-route-video"]')
      .exists();
  });
});
