import { currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Video Hub canonical watch", function () {
  test("loads the server payload and replaces a stale slug with the canonical watch path", async function (assert) {
    const payload = {
      video: {
        id: 42,
        provider: "youtube",
        external_id: "dQw4w9WgXcQ",
        canonical_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        kind: "landscape",
        title: "Canonical video",
        thumbnail_url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        duration_seconds: null,
        author_name: "Example creator",
        topic_id: 100,
        post_id: 101,
        published_at: "2026-08-28T12:00:00Z",
        watch_path: "/videos/42/canonical-video",
      },
    };

    pretender.get("/videos/42/wrong-slug.json", () => response(payload));
    pretender.get("/videos/42/canonical-video.json", () => response(payload));

    await visit("/videos/42/wrong-slug");

    assert.strictEqual(currentURL(), "/videos/42/canonical-video");
    assert.dom(".video-hub-watch__details h1").hasText("Canonical video");
    assert.dom(".video-hub-watch__author").hasText("Example creator");
    assert
      .dom(".video-hub-watch__media img")
      .hasAttribute("src", "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")
      .hasAttribute("alt", "Canonical video");
    assert
      .dom(".video-hub-watch__provider-link")
      .hasAttribute("href", "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
      .hasText("Watch on YouTube");
  });
});
