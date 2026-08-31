import Service from "@ember/service";
import { render, settled, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";
import VideoHubLanding from "discourse/plugins/discourse-video-hub/discourse/components/video-hub-landing";

class DesktopCapabilities extends Service {
  viewport = { sm: true };
}

module(
  "Integration | Component | VideoHubLanding | immersive explore",
  function (hooks) {
    setupRenderingTest(hooks, { anonymous: true });

    hooks.beforeEach(function () {
      this.owner.register("service:capabilities", DesktopCapabilities);
    });

    test("keeps one active player, prefetches near the end, dedupes, and supports keyboard navigation", async function (assert) {
      const observations = stubIntersectionObserver();
      const model = {
        videos: [
          {
            id: 100,
            provider: "youtube",
            external_id: "dQw4w9WgXcQ",
            kind: "shorts",
            title: "First explore video",
            thumbnail_url: null,
            author_name: "First creator",
            watch_path: "/videos/100/first-explore-video",
          },
          {
            id: 101,
            provider: "youtube",
            external_id: "9bZkp7q19f0",
            kind: "shorts",
            title: "Second explore video",
            thumbnail_url: null,
            author_name: "Second creator",
            watch_path: "/videos/101/second-explore-video",
          },
        ],
        providers: ["youtube"],
        pagination: { has_more: true, next_cursor: "cursor-1" },
      };
      let requestCount = 0;

      pretender.get("/videos/feed.json", (request) => {
        requestCount += 1;
        const cursor = new URL(
          request.url,
          window.location.origin
        ).searchParams.get("cursor");
        assert.strictEqual(
          cursor,
          "cursor-1",
          "prefetches with the server cursor"
        );

        return response({
          videos: [
            model.videos[1],
            {
              id: 102,
              provider: "youtube",
              external_id: "M7lc1UVf-VE",
              kind: "landscape",
              title: "Third explore video",
              thumbnail_url: null,
              author_name: "Third creator",
              watch_path: "/videos/102/third-explore-video",
            },
          ],
          providers: ["youtube"],
          pagination: { has_more: false, next_cursor: null },
        });
      });

      await render(
        <template>
          <VideoHubLanding @model={{model}} @immersive={{true}} />
        </template>
      );

      assert.dom(".video-hub-explore").exists();
      assert.dom(".video-hub-page__hero").doesNotExist();
      assert.dom(".video-hub-mobile-feed--immersive").exists();
      assert.dom(".video-hub-mobile-feed__item").exists({ count: 2 });
      assert.dom(".video-hub-player__iframe").exists({ count: 1 });
      assert
        .dom('[data-video-hub-feed-index="0"]')
        .hasAttribute("data-active", "true");
      assert
        .dom('[data-video-hub-feed-index="0"] .video-hub-player__iframe')
        .hasAttribute(
          "src",
          "https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&mute=1&playsinline=1&loop=1&playlist=dQw4w9WgXcQ"
        );

      assert.strictEqual(observations.length, 2);
      await observations[1].trigger({ intersectionRatio: 0.8 });
      await settled();

      assert.strictEqual(requestCount, 1, "loads the next page automatically");
      assert.dom(".video-hub-mobile-feed__item").exists({ count: 3 });
      assert
        .dom('[data-video-hub-feed-index="1"]')
        .hasAttribute("data-active", "true");
      assert.dom(".video-hub-player__iframe").exists({ count: 1 });
      assert
        .dom('[data-video-hub-feed-index="1"] .video-hub-player__iframe')
        .hasAttribute(
          "src",
          "https://www.youtube.com/embed/9bZkp7q19f0?autoplay=1&mute=1&playsinline=1&loop=1&playlist=9bZkp7q19f0"
        );
      assert
        .dom('[data-video-id="101"]')
        .exists({ count: 1 }, "does not duplicate an existing canonical video");

      await triggerKeyEvent(
        '[data-video-hub-feed-index="1"]',
        "keydown",
        "ArrowDown"
      );

      assert
        .dom('[data-video-hub-feed-index="2"]')
        .hasAttribute(
          "data-active",
          "true",
          "keyboard navigation advances one card"
        );
      assert.dom(".video-hub-player__iframe").exists({ count: 1 });
      assert.strictEqual(
        requestCount,
        1,
        "does not fetch after pagination is exhausted"
      );
    });
  }
);
