import { currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";

acceptance("Video Hub immersive explore | anonymous", function () {
  test("opens the ranked discovery feed as a full-screen one-player experience", async function (assert) {
    const observations = stubIntersectionObserver();
    let requests = 0;

    pretender.get("/videos/feed.json", () => {
      requests += 1;
      return response({
        videos: [
          {
            id: 90,
            provider: "youtube",
            external_id: "dQw4w9WgXcQ",
            kind: "shorts",
            title: "Immersive route video",
            thumbnail_url: null,
            author_name: "Explore creator",
            watch_path: "/videos/90/immersive-route-video",
          },
          {
            id: 91,
            provider: "youtube",
            external_id: "9bZkp7q19f0",
            kind: "shorts",
            title: "Second immersive video",
            thumbnail_url: null,
            author_name: "Second creator",
            watch_path: "/videos/91/second-immersive-video",
          },
        ],
        providers: ["youtube"],
        pagination: { has_more: false, next_cursor: null },
      });
    });

    await visit("/videos/explore");

    assert.strictEqual(requests, 1);
    assert.strictEqual(currentURL(), "/videos/explore");
    assert.dom(".video-hub-explore").exists();
    assert.dom(".video-hub-mobile-feed--immersive").exists();
    assert.dom(".video-hub-mobile-feed__item").exists({ count: 2 });
    assert.dom(".video-hub-player__iframe").exists({ count: 1 });
    assert
      .dom('[data-video-hub-feed-index="0"] .video-hub-player__iframe')
      .hasAttribute(
        "src",
        "https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&mute=1&playsinline=1&loop=1&playlist=dQw4w9WgXcQ&controls=1"
      )
      .hasAttribute("data-interactive", "false");
    assert.dom(".video-hub-mobile-feed__actions").exists({ count: 2 });
    assert.dom(".video-hub-explore__back").hasAttribute("href", "/videos");
    assert.strictEqual(observations.length, 2, "observes each immersive card");
  });

  test("exposes Explore from the normal Video Hub landing page", async function (assert) {
    pretender.get("/videos/feed.json", () =>
      response({
        videos: [],
        providers: ["youtube"],
        pagination: { has_more: false, next_cursor: null },
      })
    );

    await visit("/videos");

    assert
      .dom(".video-hub-page__explore-link")
      .hasAttribute("href", "/videos/explore")
      .hasText("Explore");
  });
});
