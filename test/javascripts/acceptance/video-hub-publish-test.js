import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Video Hub publish", function () {
  test("posts only the publish inputs and routes to the canonical watch path", async function (assert) {
    const canonicalUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ";
    const payload = {
      video: {
        id: 42,
        provider: "youtube",
        external_id: "dQw4w9WgXcQ",
        canonical_url: canonicalUrl,
        kind: "landscape",
        title: "Published video",
        thumbnail_url: null,
        duration_seconds: null,
        author_name: "Example creator",
        topic_id: 100,
        post_id: 101,
        published_at: "2026-08-28T12:00:00Z",
        watch_path: "/videos/42/published-video",
      },
    };
    let publishRequests = 0;

    pretender.post("/videos", (request) => {
      publishRequests += 1;
      const params = new URLSearchParams(request.requestBody);

      assert.strictEqual(params.get("url"), canonicalUrl);
      assert.strictEqual(params.get("caption"), "A short caption");
      assert.strictEqual(
        params.get("provider"),
        null,
        "does not submit provider truth"
      );
      assert.strictEqual(
        params.get("external_id"),
        null,
        "does not submit provider identity"
      );

      return response(201, payload);
    });
    pretender.get("/videos/42/published-video.json", () => response(payload));
    pretender.get("/t/100.json", () =>
      response({
        id: 100,
        post_stream: {
          posts: [
            {
              id: 101,
              post_number: 1,
              username: "video-owner",
              cooked: "<p>Video root post</p>",
              actions_summary: [],
            },
          ],
        },
      })
    );
    pretender.get("/posts/101/replies.json", () => response([]));

    await visit("/videos/new");

    assert.strictEqual(currentURL(), "/videos/new");
    assert.dom(".video-hub-publish").exists();
    assert.dom('input[name="url"]').exists();
    assert.dom('textarea[name="caption"]').exists();

    await fillIn('input[name="url"]', canonicalUrl);
    await fillIn('textarea[name="caption"]', "A short caption");
    await click('.video-hub-publish button[type="submit"]');

    assert.strictEqual(publishRequests, 1);
    assert.strictEqual(currentURL(), "/videos/42/published-video");
    assert.dom(".video-hub-watch__details h1").hasText("Published video");
  });

  test("fails closed when the publish response has no canonical watch path", async function (assert) {
    pretender.post("/videos", () =>
      response(201, {
        video: {
          id: 42,
          watch_path: "https://example.com/not-allowed",
        },
      })
    );

    await visit("/videos/new");
    await fillIn(
      'input[name="url"]',
      "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    );
    await click('.video-hub-publish button[type="submit"]');

    assert.strictEqual(currentURL(), "/videos/new");
    assert
      .dom(".video-hub-publish .alert-error")
      .hasText(
        "The video was published, but the watch page response was invalid."
      );
  });
});
